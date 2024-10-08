// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {InfraStorageSetters} from "./Libraries/InfraStorageSetters.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {IInfraOrchestrator, IOrchestratorViewDelegate} from "./Interfaces/IInfraOrchestrator.sol";
import {InfraCommon} from "./InfraCommon.sol";
import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON, USDC_AVALANCHE, CHAIN_SELECTOR_ARBITRUM, CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON, CHAIN_SELECTOR_AVALANCHE} from "./Constants.sol";
import {IInfraCLF} from "./Interfaces/IInfraCLF.sol";

///////////////////////////////
/////////////ERROR/////////////
///////////////////////////////
///@notice error emitted when the balance input is smaller than the specified amount param
error InvalidAmount();
///@notice error emitted when a address non-router calls the `handleOracleFulfillment` function
error OnlyCLFRouter();
///@notice error emitted when some params of Bridge Data are empty
error InvalidBridgeData();
///@notice error emitted when an empty swapData is the input
error InvalidSwapData();
///@notice error emitted when the token to bridge is not USDC
error UnsupportedBridgeToken();

contract InfraOrchestrator is
    IFunctionsClient,
    IInfraOrchestrator,
    InfraCommon,
    InfraStorageSetters
{
    using SafeERC20 for IERC20;

    ///////////////
    ///CONSTANTS///
    ///////////////
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;

    ///////////////
    ///IMMUTABLE///
    ///////////////
    ///@notice the address of Functions router
    address internal immutable i_functionsRouter;
    ///@notice variable to store the DexSwap address
    address internal immutable i_dexSwap;
    ///@notice variable to store the Concero address
    address internal immutable i_concero;
    ///@notice variable to store the ConceroPool address
    address internal immutable i_pool;
    ///@notice variable to store the immutable Proxy Address
    address internal immutable i_proxy;
    ///@notice ID of the deployed chain on getChain() function
    Chain internal immutable i_chainIndex;

    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _concero,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    ) InfraCommon(_messengers) InfraStorageSetters(msg.sender) {
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

    modifier validateBridgeData(BridgeData memory _bridgeData) {
        if (_bridgeData.amount == 0 || _bridgeData.receiver == address(0)) {
            revert InvalidBridgeData();
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
            revert InvalidSwapData();
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
            revert InvalidSwapData();
        }

        if (swapDataLength > 5 || (swapDataLength != 0 && _swapData[0].fromAmount == 0)) {
            revert InvalidSwapData();
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
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IConceroBridge.getSrcTotalFeeInUSDC.selector,
            tokenType,
            dstChainSelector,
            amount
        );

        bytes memory delegateCallRes = LibConcero.safeDelegateCall(i_concero, delegateCallArgs);

        return _convertToUSDCDecimals(abi.decode(delegateCallRes, (uint256)));
    }

    /**
     * @notice Function To swap a token into a bridgeable one and start bridging
     * @param bridgeData the payload to bridge token
     * @param srcSwapData the payload to swap on src
     * @param dstSwapData the payload to swap on dst, if it's not empty.
     */
    function swapAndBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] calldata srcSwapData,
        IDexSwap.SwapData[] memory dstSwapData
    )
        external
        payable
        validateSrcSwapData(srcSwapData)
        validateBridgeData(bridgeData)
        validateDstSwapData(dstSwapData, bridgeData)
        nonReentrant
    {
        if (
            srcSwapData[srcSwapData.length - 1].toToken !=
            getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex)
        ) {
            revert InvalidSwapData();
        }

        uint256 amountReceivedFromSwap = _swap(srcSwapData, address(this), false);
        bridgeData.amount = amountReceivedFromSwap;

        _bridge(bridgeData, dstSwapData);
    }

    /**
     * @notice external function to start swap
     * @param _swapData the swap payload
     * @param _receiver the receiver of the swapped amount
     */
    function swap(
        IDexSwap.SwapData[] calldata _swapData,
        address _receiver
    ) external payable validateSrcSwapData(_swapData) nonReentrant {
        _swap(_swapData, _receiver, true);
    }

    /**
     * @notice function to start a bridge transaction
     * @param bridgeData the bridge payload
     * @param dstSwapData the destination swap payload, if not empty.
     */
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
        address fromToken = getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex);
        LibConcero.transferFromERC20(fromToken, msg.sender, address(this), bridgeData.amount);

        _bridge(bridgeData, dstSwapData);
    }

    /**
     * @notice Wrapper function to delegate call to ConceroBridge.addUnconfirmedTX
     * @param ccipMessageId the CCIP message ID to be added on destination
     * @param sender the address of the sender
     * @param recipient the address of recipient of the bridge transaction
     * @param amount the amount to be bridged
     * @param srcChainSelector the CCIP chain selector of source chain
     * @param token the address of the token
     * @param blockNumber the transaction block number
     * @param dstSwapData the swap data to perform, if it's not empty
     */
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
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IInfraCLF.addUnconfirmedTX.selector,
            ccipMessageId,
            sender,
            recipient,
            amount,
            srcChainSelector,
            token,
            blockNumber,
            dstSwapData
        );

        LibConcero.safeDelegateCall(i_concero, delegateCallArgs);
    }

    /**
     * @notice Helper function to delegate call to ConceroBridge contract
     * @param requestId the CLF request ID from callback
     * @param response the response
     * @param err the error
     * @dev response and error will never be populated at the same time.
     */
    function handleOracleFulfillment(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external {
        //todo: research if this is worth moving to a modifier
        if (msg.sender != address(i_functionsRouter)) {
            revert OnlyCLFRouter();
        }

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IInfraCLF.fulfillRequestWrapper.selector,
            requestId,
            response,
            err
        );

        LibConcero.safeDelegateCall(i_concero, delegateCallArgs);
    }

    /**
     * @notice Function to allow Concero Team to withdraw
     * @param recipient the recipient address
     * @param token the token to withdraw
     * @param amount the amount to withdraw
     */
    function withdraw(address recipient, address token, uint256 amount) external payable onlyOwner {
        uint256 balance = LibConcero.getBalance(token, address(this));
        if (balance < amount) revert InvalidAmount();

        if (token != address(0)) {
            LibConcero.transferERC20(token, amount, recipient);
        } else {
            payable(recipient).transfer(amount);
        }
    }

    //////////////////////////
    /// INTERNAL FUNCTIONS ///
    //////////////////////////
    /**
     * @notice Internal function to perform swaps. Delegate calls DexSwap.entrypoint
     * @param swapData the payload to be passed to swap functions
     * @param receiver the address of the receiver of the swap
     * @param isTakingConceroFee flag to indicate when take fees
     */
    function _swap(
        IDexSwap.SwapData[] memory swapData,
        address receiver,
        bool isTakingConceroFee
    ) internal returns (uint256) {
        address srcToken = swapData[0].fromToken;
        uint256 srcAmount = swapData[0].fromAmount;

        if (srcToken != address(0)) {
            LibConcero.transferFromERC20(srcToken, msg.sender, address(this), srcAmount);
            if (isTakingConceroFee) swapData[0].fromAmount -= (srcAmount / CONCERO_FEE_FACTOR);
        } else {
            if (srcAmount != msg.value) revert InvalidAmount();

            if (isTakingConceroFee) {
                swapData[0].fromAmount = srcAmount - (srcAmount / CONCERO_FEE_FACTOR);
            }
        }

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IDexSwap.entrypoint.selector,
            swapData,
            receiver
        );
        bytes memory delegateCallRes = LibConcero.safeDelegateCall(i_dexSwap, delegateCallArgs);

        return abi.decode(delegateCallRes, (uint256));
    }

    function _bridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory _dstSwapData
    ) internal {
        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IConceroBridge.startBridge.selector,
            bridgeData,
            _dstSwapData
        );

        bytes memory delegateCallRes = LibConcero.safeDelegateCall(i_concero, delegateCallArgs);
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
            revert UnsupportedBridgeToken();
        }
    }

    ///////////////////////////
    ///VIEW & PURE FUNCTIONS///
    ///////////////////////////
    function getTransaction(
        bytes32 _conceroBridgeTxId
    ) external view returns (Transaction memory transaction) {
        transaction = s_transactions[_conceroBridgeTxId];
    }

    function isTxConfirmed(bytes32 _txId) external view returns (bool) {
        Transaction storage tx = s_transactions[_txId];

        if (tx.messageId == bytes32(0)) {
            return false;
        }
        if (!tx.isConfirmed) {
            return false;
        }
        return true;
    }
}
