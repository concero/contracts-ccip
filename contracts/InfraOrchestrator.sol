// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {CHAIN_SELECTOR_ARBITRUM, CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON, CHAIN_SELECTOR_AVALANCHE, USDC_ARBITRUM, USDC_BASE, USDC_POLYGON, USDC_AVALANCHE} from "./Constants.sol";
import {InfraCommon} from "./InfraCommon.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IInfraCLF} from "./Interfaces/IInfraCLF.sol";
import {IInfraOrchestrator, IOrchestratorViewDelegate} from "./Interfaces/IInfraOrchestrator.sol";
import {IInfraStorage} from "./Interfaces/IInfraStorage.sol";
import {InfraStorage} from "./Libraries/InfraStorage.sol";
import {InfraStorageSetters} from "./Libraries/InfraStorageSetters.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/* ERRORS */
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
error WithdrawableAmountExceedsBatchedReserves();
error InvalidIntegratorFeeBps();
error FailedToWithdrawIntegratorFees();

contract InfraOrchestrator is
    IFunctionsClient,
    IInfraOrchestrator,
    InfraCommon,
    InfraStorageSetters
{
    using SafeERC20 for IERC20;

    /* CONSTANT VARIABLES */
    uint8 internal constant SUPPORTED_CHAINS_COUNT = 5;
    uint16 internal constant MAX_INTEGRATOR_FEE_BPS = 1000;
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;
    uint16 internal constant INTEGRATOR_FEE_DIVISOR = 10000;

    /* IMMUTABLE VARIABLES */
    address internal immutable i_functionsRouter;
    address internal immutable i_dexSwap;
    address internal immutable i_conceroBridge;
    address internal immutable i_pool;
    address internal immutable i_proxy;
    Chain internal immutable i_chainIndex;

    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _conceroBridge,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    ) InfraCommon(_messengers) InfraStorageSetters(msg.sender) {
        i_functionsRouter = _functionsRouter;
        i_dexSwap = _dexSwap;
        i_conceroBridge = _conceroBridge;
        i_pool = _pool;
        i_proxy = _proxy;
        i_chainIndex = Chain(_chainIndex);
    }

    receive() external payable {}

    /* MODIFIERS */
    modifier validateBridgeData(BridgeData memory _bridgeData) {
        if (_bridgeData.amount == 0 || _bridgeData.receiver == address(0)) {
            revert InvalidBridgeData();
        }
        _;
    }

    modifier validateSrcSwapData(IDexSwap.SwapData[] memory _swapData) {
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

    /* VIEW FUNCTIONS */
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

        bytes memory delegateCallRes = LibConcero.safeDelegateCall(
            i_conceroBridge,
            delegateCallArgs
        );

        return _convertToUSDCDecimals(abi.decode(delegateCallRes, (uint256)));
    }

    /**
     * @notice Performs a bridge coupled with the source chain swap and an optional destination chain swap.
     * @param bridgeData bridge payload of type BridgeData
     * @param srcSwapData swap payload for the source chain of type IDexSwap.SwapData[]
     * @param dstSwapData swap payload for the destination chain of type IDexSwap.SwapData[]. May be empty
     */
    function swapAndBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] calldata srcSwapData,
        IDexSwap.SwapData[] memory dstSwapData,
        Integration memory integration
    )
        external
        payable
        validateSrcSwapData(srcSwapData)
        validateBridgeData(bridgeData)
        validateDstSwapData(dstSwapData, bridgeData)
        nonReentrant
    {
        address usdc = getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex);

        if (srcSwapData[srcSwapData.length - 1].toToken != usdc) {
            revert InvalidSwapData();
        }

        _transferTokenFromUser(srcSwapData);

        uint256 amountReceivedFromSwap = _swap(srcSwapData, address(this));
        bridgeData.amount =
            amountReceivedFromSwap -
            _collectIntegratorFee(usdc, amountReceivedFromSwap, integration);

        _bridge(bridgeData, dstSwapData);
    }

    /**
     * @notice Performs a swap on a single chain.
     * @param swapData the swap payload of type IDexSwap.SwapData[]
     * @param receiver the recipient of the swap
     * @param integration the integrator fee data
     */
    function swap(
        IDexSwap.SwapData[] memory swapData,
        address receiver,
        Integration memory integration
    ) external payable validateSrcSwapData(swapData) nonReentrant {
        _transferTokenFromUser(swapData);
        swapData = _collectSwapFee(swapData, integration);
        _swap(swapData, receiver);
    }

    /**
     * @notice Performs a bridge from the source chain to the destination chain.
     * @param bridgeData bridge payload of type BridgeData
     * @param dstSwapData destination swap payload. May be empty
     */
    function bridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData,
        Integration memory integration
    )
        external
        payable
        validateBridgeData(bridgeData)
        validateDstSwapData(dstSwapData, bridgeData)
        nonReentrant
    {
        address fromToken = getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex);
        LibConcero.transferFromERC20(fromToken, msg.sender, address(this), bridgeData.amount);
        bridgeData.amount -= _collectIntegratorFee(fromToken, bridgeData.amount, integration);

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

        LibConcero.safeDelegateCall(i_conceroBridge, delegateCallArgs);
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
        if (msg.sender != address(i_functionsRouter)) {
            revert OnlyCLFRouter();
        }

        bytes memory delegateCallArgs = abi.encodeWithSelector(
            IInfraCLF.fulfillRequestWrapper.selector,
            requestId,
            response,
            err
        );

        LibConcero.safeDelegateCall(i_conceroBridge, delegateCallArgs);
    }

    function withdrawIntegratorFees(address token) external nonReentrant {
        uint256 amount = s_integratorFeesAmountByToken[msg.sender][token];
        if (amount == 0) {
            revert FailedToWithdrawIntegratorFees();
        }

        s_integratorFeesAmountByToken[msg.sender][token] = 0;
        s_totalIntegratorFeesAmountByToken[token] -= amount;

        if (token != address(0)) {
            IERC20(token).safeTransfer(msg.sender, amount);
        } else {
            (bool success, ) = msg.sender.call{value: amount}("");

            if (!success) {
                revert FailedToWithdrawIntegratorFees();
            }
        }

        emit IntegratorFeesWithdrawn(msg.sender, token, amount);
    }

    /**
     * @notice Function to allow Concero Team to withdraw fees
     * @param recipient the recipient address
     * @param token the token to withdraw
     * @param amount the amount to withdraw
     */
    function withdrawConceroFees(
        address recipient,
        address token,
        uint256 amount
    ) external payable onlyOwner {
        uint256 balance = LibConcero.getBalance(token, address(this));
        if (balance < amount) revert InvalidAmount();

        address usdc = getUSDCAddressByChainIndex(CCIPToken.usdc, i_chainIndex);

        if (token == usdc) {
            uint256 batchedReserves;
            uint64[SUPPORTED_CHAINS_COUNT] memory chainSelectors = [
                CHAIN_SELECTOR_ARBITRUM,
                CHAIN_SELECTOR_BASE,
                CHAIN_SELECTOR_OPTIMISM,
                CHAIN_SELECTOR_POLYGON,
                CHAIN_SELECTOR_AVALANCHE
            ];

            for (uint256 i; i < SUPPORTED_CHAINS_COUNT; ++i) {
                batchedReserves += s_pendingSettlementTxAmountByDstChain[chainSelectors[i]];
            }

            if (amount > balance - batchedReserves) {
                revert WithdrawableAmountExceedsBatchedReserves();
            }
        }

        if (token == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            LibConcero.transferERC20(token, amount, recipient);
        }
    }

    function getTransaction(
        bytes32 _conceroBridgeTxId
    ) external view returns (Transaction memory transaction) {
        transaction = s_transactions[_conceroBridgeTxId];
    }

    function isTxConfirmed(bytes32 _txId) external view returns (bool) {
        Transaction storage transaction = s_transactions[_txId];

        if (transaction.messageId == bytes32(0)) {
            return false;
        }
        if (!transaction.isConfirmed) {
            return false;
        }
        return true;
    }

    /* INTERNAL FUNCTIONS */

    function _transferTokenFromUser(IDexSwap.SwapData[] memory swapData) internal {
        address initialToken = swapData[0].fromToken;
        uint256 initialAmount = swapData[0].fromAmount;

        if (initialToken != address(0)) {
            LibConcero.transferFromERC20(initialToken, msg.sender, address(this), initialAmount);
        } else {
            if (initialAmount != msg.value) revert InvalidAmount();
        }
    }

    /**
     * @notice Internal function to perform swaps. Delegate calls DexSwap.entrypoint
     * @param swapData the payload to be passed to swap functions
     * @param receiver the address of the receiver of the swap
     */
    function _swap(
        IDexSwap.SwapData[] memory swapData,
        address receiver
    ) internal returns (uint256) {
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
            IConceroBridge.bridge.selector,
            bridgeData,
            _dstSwapData
        );

        LibConcero.safeDelegateCall(i_conceroBridge, delegateCallArgs);
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

    function _collectSwapFee(
        IDexSwap.SwapData[] memory swapData,
        Integration memory integration
    ) internal returns (IDexSwap.SwapData[] memory) {
        swapData[0].fromAmount -= (swapData[0].fromAmount / CONCERO_FEE_FACTOR);

        swapData[0].fromAmount -= _collectIntegratorFee(
            swapData[0].fromToken,
            swapData[0].fromAmount,
            integration
        );

        return swapData;
    }

    function _collectIntegratorFee(
        address token,
        uint256 amount,
        Integration memory integration
    ) internal returns (uint256) {
        if (integration.integrator == address(0)) return 0;

        uint256 integratorFeeAmount = _calculateIntegratorFeeAmount(integration.feeBps, amount);

        if (integratorFeeAmount == 0) return 0;

        s_integratorFeesAmountByToken[integration.integrator][token] += integratorFeeAmount;
        s_totalIntegratorFeesAmountByToken[token] += integratorFeeAmount;

        emit IntegratorFeesCollected(integration.integrator, token, integratorFeeAmount);
        return integratorFeeAmount;
    }

    /* VIEW & PURE FUNCTIONS */

    /// @notice calculates integrator fee amount
    /// @param integratorFeeBps fee percent provided by integrator/user
    /// @param amount user's tx amount
    /// @return integratorFeeAmount the amount the integrator will receive
    function _calculateIntegratorFeeAmount(
        uint256 integratorFeeBps,
        uint256 amount
    ) internal pure returns (uint256) {
        if (integratorFeeBps == 0) return 0;
        if (integratorFeeBps > MAX_INTEGRATOR_FEE_BPS) {
            revert InvalidIntegratorFeeBps();
        }
        return (amount * integratorFeeBps) / INTEGRATOR_FEE_DIVISOR;
    }
}
