// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {StorageSetters} from "./Libraries/StorageSetters.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {IOrchestrator, IOrchestratorViewDelegate} from "./Interfaces/IOrchestrator.sol";
import {ConceroCommon} from "./ConceroCommon.sol";
import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON, USDC_AVALANCHE, CHAIN_SELECTOR_ARBITRUM, CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON, CHAIN_SELECTOR_AVALANCHE} from "./Constants.sol";
import {IConceroFunctions} from "./Interfaces/IConceroFunctions.sol";

///////////////////////////////
/////////////ERROR/////////////
///////////////////////////////
///@notice error emitted when a delegatecall fails
error Orchestrator_UnableToCompleteDelegateCall(bytes delegateError);
///@notice error emitted when the balance input is smaller than the specified amount param
error Orchestrator_InvalidAmount();
///@notice error emitted when a address non-router calls the `handleOracleFulfillment` function
error Orchestrator_OnlyRouterCanFulfill();
///@notice error emitted when some params of Bridge Data are empty
error Orchestrator_InvalidBridgeData();
///@notice error emitted when an empty swapData is the input
error Orchestrator_InvalidSwapData();
///@notice error emitted when the token to bridge is not USDC
error Orchestrator_InvalidBridgeToken();

contract Orchestrator is IFunctionsClient, IOrchestrator, ConceroCommon, StorageSetters {
    using SafeERC20 for IERC20;

    ///////////////
    ///CONSTANTS///
    ///////////////
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;

    ///////////////
    ///IMMUTABLE///
    ///////////////
    ///@notice the address of Functions router
    address immutable i_functionsRouter;
    ///@notice variable to store the DexSwap address
    address immutable i_dexSwap;
    ///@notice variable to store the Concero address
    address immutable i_concero;
    ///@notice variable to store the ConceroPool address
    address immutable i_pool;
    ///@notice variable to store the immutable Proxy Address
    address immutable i_proxy;
    ///@notice ID of the deployed chain on getChain() function
    Chain internal immutable i_chainIndex;

    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////
    ///@notice emitted when the Functions router fulfills a request
    event Orchestrator_RequestFulfilled(bytes32 requestId);
    ///@notice emitted if swap successed
    event Orchestrator_SwapSuccess();
    event Orchestrator_StartBridge();
    event Orchestrator_StartSwapAndBridge();
    event Orchestrator_StartSwap();

    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _concero,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    ) ConceroCommon(_messengers) StorageSetters(msg.sender) {
        i_functionsRouter = _functionsRouter;
        i_dexSwap = _dexSwap;
        i_concero = _concero;
        i_pool = _pool;
        i_proxy = _proxy;
        i_chainIndex = Chain(_chainIndex);
    }

    receive() external payable {}

    ///////////////
    ///MODIFIERS///
    ///////////////
    // todo: this modifier may be removed
    modifier tokenAmountSufficiency(address token, uint256 amount) {
        if (token != address(0)) {
            uint256 balance = IERC20(token).balanceOf(msg.sender);
            if (balance < amount) revert Orchestrator_InvalidAmount();
        } else {
            if (msg.value != amount) revert Orchestrator_InvalidAmount();
        }
        _;
    }

    modifier validateBridgeData(BridgeData memory _bridgeData) {
        if (_bridgeData.amount == 0 || _bridgeData.receiver == address(0)) {
            revert Orchestrator_InvalidBridgeData();
        }
        _;
    }

    modifier validateSrcSwapData(IDexSwap.SwapData[] calldata _swapData) {
        uint256 swapDataLength = _swapData.length;

        // todo: _swapData[0].toAmountMin == 0 may not be needed. We're only checking the first item
        if (
            swapDataLength == 0 ||
            swapDataLength > 5 ||
            _swapData[0].fromAmount == 0 ||
            _swapData[0].toAmountMin == 0
        ) {
            revert Orchestrator_InvalidSwapData();
        }
        _;
    }

    modifier validateDstSwapData(
        IDexSwap.SwapData[] memory _swapData,
        BridgeData memory _bridgeData
    ) {
        uint256 swapDataLength = _swapData.length;

        if (
            swapDataLength != 0 &&
            _swapData[0].fromToken != _getUSDCAddressByChainSelector(_bridgeData.dstChainSelector)
        ) {
            revert Orchestrator_InvalidSwapData();
        }

        if (swapDataLength > 5 || (swapDataLength != 0 && _swapData[0].fromAmount == 0)) {
            revert Orchestrator_InvalidSwapData();
        }

        _;
    }

    ////////////////////////
    /////VIEW FUNCTIONS/////
    ////////////////////////

    function getSrcTotalFeeInUSDC(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256) {
        return
            IOrchestratorViewDelegate(address(this)).getSrcTotalFeeInUSDCViaDelegateCall(
                tokenType,
                dstChainSelector,
                amount
            );
    }

    function getSrcTotalFeeInUSDCViaDelegateCall(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external returns (uint256) {
        (bool success, bytes memory data) = i_concero.delegatecall(
            abi.encodeWithSelector(
                IConceroBridge.getSrcTotalFeeInUSDC.selector,
                tokenType,
                dstChainSelector,
                amount
            )
        );

        if (!success) revert Orchestrator_UnableToCompleteDelegateCall(data);
        return _convertToUSDCDecimals(abi.decode(data, (uint256)));
    }

    function swapAndBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] calldata srcSwapData,
        IDexSwap.SwapData[] memory dstSwapData
    )
        external
        payable
        tokenAmountSufficiency(srcSwapData[0].fromToken, srcSwapData[0].fromAmount)
        validateSrcSwapData(srcSwapData)
        validateBridgeData(bridgeData)
        validateDstSwapData(dstSwapData, bridgeData)
        nonReentrant
    {
        // todo: do not use events at the start of the function, this can be moved to the end of the function, after all potential reverts
        emit Orchestrator_StartSwapAndBridge();
        if (
            srcSwapData[srcSwapData.length - 1].toToken !=
            getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex)
        ) revert Orchestrator_InvalidSwapData();

        uint256 amountReceivedFromSwap = _swap(srcSwapData, 0, false, address(this));
        bridgeData.amount = amountReceivedFromSwap;

        _startBridge(bridgeData, dstSwapData);
    }

    function swap(
        IDexSwap.SwapData[] calldata _swapData,
        address _receiver
    )
        external
        payable
        validateSrcSwapData(_swapData)
        tokenAmountSufficiency(_swapData[0].fromToken, _swapData[0].fromAmount)
        nonReentrant
    {
        // todo: do not use events at the start of the function
        // todo: this can be moved to the end of the function, after all potential reverts
        emit Orchestrator_StartSwap();
        _swap(_swapData, msg.value, true, _receiver);
    }

    function bridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    )
        external
        payable
        validateBridgeData(bridgeData)
        validateDstSwapData(dstSwapData, bridgeData)
        nonReentrant
    {
        // todo: do not use events at the start of the function
        // todo: this can be moved to the end of the function, after all potential reverts
        emit Orchestrator_StartBridge();

        // todo: this may not be necessary, as we can simply attempt to transfer the token and revert if it fails
        // todo: maybe move to modifier tokenAmountSufficiency
        // todo: research if LIFI does this check
        uint256 userBalance = IERC20(getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex))
            .balanceOf(msg.sender);
        if (userBalance < bridgeData.amount) revert Orchestrator_InvalidAmount();
        // todo: the above can be removed

        address fromToken = getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex);
        LibConcero.transferFromERC20(fromToken, msg.sender, address(this), bridgeData.amount);

        _startBridge(bridgeData, dstSwapData);
    }

    function addUnconfirmedTX(
        bytes32 ccipMessageId,
        address sender,
        address recipient,
        uint256 amount,
        uint64 srcChainSelector,
        CCIPToken token,
        uint256 blockNumber,
        bytes calldata dstSwapData
    ) external onlyMessenger {
        (bool success, bytes memory error) = i_concero.delegatecall(
            abi.encodeWithSelector(
                IConceroFunctions.addUnconfirmedTX.selector,
                ccipMessageId,
                sender,
                recipient,
                amount,
                srcChainSelector,
                token,
                blockNumber,
                dstSwapData
            )
        );
        if (!success) revert Orchestrator_UnableToCompleteDelegateCall(error);
    }

    function handleOracleFulfillment(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external {
        //todo: research if this is worth moving to a modifier
        if (msg.sender != address(i_functionsRouter)) {
            revert Orchestrator_OnlyRouterCanFulfill();
        }

        (bool success, bytes memory error) = i_concero.delegatecall(
            abi.encodeWithSelector(
                IConceroFunctions.fulfillRequestWrapper.selector,
                requestId,
                response,
                err
            )
        );

        if (!success) revert Orchestrator_UnableToCompleteDelegateCall(error);
        emit Orchestrator_RequestFulfilled(requestId);
    }

    function withdraw(address recipient, address token, uint256 amount) external payable onlyOwner {
        uint256 balance = LibConcero.getBalance(token, address(this));
        if (balance < amount) revert Orchestrator_InvalidAmount();

        if (token != address(0)) {
            LibConcero.transferERC20(token, amount, recipient);
        } else {
            payable(recipient).transfer(amount);
        }
    }

    //////////////////////////
    /// INTERNAL FUNCTIONS ///
    //////////////////////////
    function _swap(
        IDexSwap.SwapData[] memory swapData,
        uint256 _nativeAmount,
        bool isTakingConceroFee,
        address _receiver
    ) internal returns (uint256) {
        address srcToken = swapData[0].fromToken;
        uint256 srcAmount = swapData[0].fromAmount;
        address dstToken = swapData[swapData.length - 1].toToken;

        uint256 dstTokenBalanceBefore = LibConcero.getBalance(dstToken, address(this));

        if (srcToken != address(0)) {
            LibConcero.transferFromERC20(srcToken, msg.sender, address(this), srcAmount);
            if (isTakingConceroFee) swapData[0].fromAmount -= (srcAmount / CONCERO_FEE_FACTOR);
        } else {
            if (isTakingConceroFee)
                swapData[0].fromAmount = _nativeAmount - (_nativeAmount / CONCERO_FEE_FACTOR);
        }

        (bool success, bytes memory error) = i_dexSwap.delegatecall(
            abi.encodeWithSelector(IDexSwap.entrypoint.selector, swapData, _receiver)
        );
        if (!success) revert Orchestrator_UnableToCompleteDelegateCall(error);

        emit Orchestrator_SwapSuccess();

        uint256 dstTokenBalanceAfter = LibConcero.getBalance(dstToken, address(this));
        return dstTokenBalanceAfter - dstTokenBalanceBefore;
    }

    function _startBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory _dstSwapData
    ) internal {
        (bool success, bytes memory error) = i_concero.delegatecall(
            abi.encodeWithSelector(IConceroBridge.startBridge.selector, bridgeData, _dstSwapData)
        );
        if (!success) revert Orchestrator_UnableToCompleteDelegateCall(error);
    }

    function _getUSDCAddressByChainSelector(
        uint64 _chainSelector
    ) internal pure returns (address _token) {
        if (_chainSelector == CHAIN_SELECTOR_ARBITRUM) {
            _token = USDC_ARBITRUM;
        } else if (_chainSelector == CHAIN_SELECTOR_BASE) {
            _token = USDC_BASE;
        } else if (_chainSelector == CHAIN_SELECTOR_POLYGON) {
            _token = USDC_POLYGON;
        } else if (_chainSelector == CHAIN_SELECTOR_AVALANCHE) {
            _token = USDC_AVALANCHE;
        } else {
            revert Orchestrator_InvalidBridgeToken();
        }
    }

    ///////////////////////////
    ///VIEW & PURE FUNCTIONS///
    ///////////////////////////
    function getTransaction(
        bytes32 _ccipMessageId
    ) external view returns (Transaction memory transaction) {
        transaction = s_transactions[_ccipMessageId];
    }
}
