// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IConceroBridge} from "./Interfaces/IConceroBridge.sol";
import {IStorage} from "contracts/Interfaces/IStorage.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the input amount is less than the fees
error ConceroBridge_InsufficientFees(uint256 amount, uint256 fee);
///@notice error emitted when a non orchestrator address call startBridge
error ConceroBridge_OnlyProxyContext(address caller);

contract ConceroBridge is IConceroBridge, ConceroCCIP {
    using SafeERC20 for IERC20;

    ///////////////
    ///CONSTANTS///
    ///////////////
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;
    uint64 private constant HALF_DST_GAS = 600_000;
    uint256 internal constant MIN_BATCH_AMOUNT = 6_000_000_000; // 6,000 USDC
    uint256 internal constant MAX_BATCH_AMOUNT = 7_000_000_000; // 7,000 USDC
    uint256 internal constant CCIP_FEE_IN_USDC = 20_000; // 2c worth of USDC

    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////
    /// @notice event emitted when an individual tx is sent through CLF
    event ConceroBridgeSent(
        bytes32 indexed conceroMessageId,
        CCIPToken tokenType,
        uint256 amount,
        uint64 dstChainSelector,
        address receiver
    );

    /// @notice event emitted when a batched CCIP message is sent
    event ConceroSettlementSent(bytes32 indexed ccipMessageId, uint256 amount);

    constructor(
        FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    )
        ConceroCCIP(
            _variables,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            _dexSwap,
            _pool,
            _proxy,
            _messengers
        )
    {}

    ///////////////////////////////////////////////////////////////
    ///////////////////////////Functions///////////////////////////
    ///////////////////////////////////////////////////////////////
    /**
     * @notice Function responsible to trigger CCIP and start the bridging process
     * @param bridgeData The bytes data payload with transaction infos
     * @param dstSwapData The bytes data payload with destination swap Data
     * @dev dstSwapData can be empty if there is no swap on destination
     * @dev this function should only be able to called thought infra Proxy
     */
    function startBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable {
        if (address(this) != i_proxy) revert ConceroBridge_OnlyProxyContext(address(this));
        address fromToken = getUSDCAddressByChainIndex(bridgeData.tokenType, i_chainIndex);

        uint256 totalSrcFee = _convertToUSDCDecimals(
            _getSrcTotalFeeInUsdc(bridgeData.dstChainSelector, bridgeData.amount)
        );

        if (bridgeData.amount < totalSrcFee) {
            revert ConceroBridge_InsufficientFees(bridgeData.amount, totalSrcFee);
        }

        uint256 amountToSend = bridgeData.amount - totalSrcFee;
        bytes32 conceroMessageId = keccak256(
            abi.encodePacked(msg.sender, bridgeData.receiver, amountToSend, block.timestamp)
        );
        BridgeTx memory bridgeTx = BridgeTx(bridgeData.receiver, amountToSend, conceroMessageId);

        s_pendingSettlementTxsByDstChain[bridgeData.dstChainSelector].push(conceroMessageId);
        s_pendingTxsBySettlementId[conceroMessageId] = bridgeTx;
        s_pendingBatchedTxAmountByDstChain[bridgeData.dstChainSelector] += amountToSend;

        uint256 batchedTxAmount = s_pendingBatchedTxAmountByDstChain[bridgeData.dstChainSelector];

        _sendUnconfirmedTX(conceroMessageId, msg.sender, bridgeData, amountToSend, dstSwapData);
        _handleBatch(batchedTxAmount, bridgeData, fromToken, amountToSend, conceroMessageId);

        emit ConceroBridgeSent(
            conceroMessageId,
            bridgeData.tokenType,
            amountToSend,
            bridgeData.dstChainSelector,
            bridgeData.receiver
        );
    }

    /////////////////
    ///VIEW & PURE///
    /////////////////
    /**
     * @notice Function to get the total amount of fees charged by Chainlink functions in Link
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getFunctionsFeeInLink(uint64 dstChainSelector) public view returns (uint256) {
        uint256 srcGasPrice = s_lastGasPrices[CHAIN_SELECTOR];
        uint256 dstGasPrice = s_lastGasPrices[dstChainSelector];
        uint256 srcClFeeInLink = clfPremiumFees[CHAIN_SELECTOR] +
            (srcGasPrice *
                (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_SRC_CALLBACK_GAS_LIMIT) *
                s_latestLinkNativeRate) /
            1e18;

        uint256 dstClFeeInLink = clfPremiumFees[dstChainSelector] +
            ((dstGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_DST_CALLBACK_GAS_LIMIT)) *
                s_latestLinkNativeRate) /
            1e18;

        return srcClFeeInLink + dstClFeeInLink;
    }

    /**
     * @notice Function to get the total amount of fees charged by Chainlink functions in USDC
     * @param dstChainSelector the destination blockchain chain selector
     */
    function getFunctionsFeeInUsdc(uint64 dstChainSelector) public view returns (uint256) {
        //    uint256 functionsFeeInLink = getFunctionsFeeInLink(dstChainSelector);
        //    return (functionsFeeInLink * s_latestLinkUsdcRate) / STANDARD_TOKEN_DECIMALS;

        return clfPremiumFees[dstChainSelector] + clfPremiumFees[CHAIN_SELECTOR];
    }

    /**
     * @notice Function to get the total amount of CCIP fees in Link
     * @param _dstChainSelector the destination blockchain chain selector
     */
    //    function getCCIPFeeInLink(uint64 _dstChainSelector) public view returns (uint256) {
    //        return s_lastCCIPFeeInLink[_dstChainSelector];
    //    }

    /**
     * @notice Function to get the total amount of CCIP fees in USDC
     * @param _dstChainSelector the destination blockchain chain selector
     */
    function getCCIPFeeInUsdc(uint64 _dstChainSelector) public view returns (uint256) {
        //        uint256 ccipFeeInLink = getCCIPFeeInLink(_dstChainSelector);
        //        return (ccipFeeInLink * uint256(s_latestLinkUsdcRate)) / STANDARD_TOKEN_DECIMALS;

        return CCIP_FEE_IN_USDC;
    }

    function getSrcTotalFeeInUSDC(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256) {
        return _getSrcTotalFeeInUsdc(dstChainSelector, amount);
    }

    ////////////////////////////////
    ///// INTERNAl FUNCTIONS ///////
    ////////////////////////////////

    function _handleBatch(
        uint256 batchedTxAmount,
        BridgeData memory bridgeData,
        address fromToken,
        uint256 amountToSend,
        bytes32 conceroMessageId
    ) internal {
        if (batchedTxAmount >= MIN_BATCH_AMOUNT && batchedTxAmount <= MAX_BATCH_AMOUNT) {
            _sendBatchViaSettlement(fromToken, batchedTxAmount, bridgeData);
        } else if (batchedTxAmount > MAX_BATCH_AMOUNT) {
            _sendExcessViaSettlement(bridgeData, fromToken, amountToSend, conceroMessageId);
        }
    }

    function _sendBatchViaSettlement(
        address fromToken,
        uint256 batchedTxAmount,
        BridgeData memory bridgeData
    ) internal {
        bytes32[] memory pendingCCIPTransactionsByDstChain = s_pendingSettlementTxsByDstChain[
            bridgeData.dstChainSelector
        ];

        BridgeTx[] memory bridgeTxs = new BridgeTx[](pendingCCIPTransactionsByDstChain.length);

        for (uint256 i; i < pendingCCIPTransactionsByDstChain.length; ++i) {
            bytes32 txId = pendingCCIPTransactionsByDstChain[i];
            BridgeTx memory bridgeTx = s_pendingTxsBySettlementId[txId];
            bridgeTxs[i] = bridgeTx;
        }

        delete s_pendingSettlementTxsByDstChain[bridgeData.dstChainSelector];
        s_pendingBatchedTxAmountByDstChain[bridgeData.dstChainSelector] = 0;

        bytes32 ccipMessageId = _sendTokenPayLink(
            bridgeData.dstChainSelector,
            fromToken,
            batchedTxAmount,
            bridgeTxs
        );
        emit ConceroSettlementSent(ccipMessageId, batchedTxAmount);
    }

    function _sendExcessViaSettlement(
        BridgeData memory bridgeData,
        address fromToken,
        uint256 amountToSend,
        bytes32 conceroMessageId
    ) internal {
        s_pendingBatchedTxAmountByDstChain[bridgeData.dstChainSelector] -= amountToSend;
        s_pendingSettlementTxsByDstChain[bridgeData.dstChainSelector].pop();

        BridgeTx[] memory bridgeTxs = new BridgeTx[](1);
        bridgeTxs[0] = s_pendingTxsBySettlementId[conceroMessageId];

        bytes32 ccipMessageId = _sendTokenPayLink(
            bridgeData.dstChainSelector,
            fromToken,
            amountToSend,
            bridgeTxs
        );
        emit ConceroSettlementSent(ccipMessageId, amountToSend);
    }

    /**
     * @notice Function to get the total amount of fees on the source
     * @param dstChainSelector the destination blockchain chain selector
     * @param amount the amount of value the fees will calculated over.
     */
    function _getSrcTotalFeeInUsdc(
        uint64 dstChainSelector,
        uint256 amount
    ) internal view returns (uint256) {
        // @notice cl functions fee
        uint256 functionsFeeInUsdc = getFunctionsFeeInUsdc(dstChainSelector);

        // @notice cl ccip fee
        /// Replaced with 2c constant CCIP_FEE_IN_USDC
        // uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(dstChainSelector);

        // @notice concero fee
        uint256 conceroFee = amount / CONCERO_FEE_FACTOR;

        // @notice gas fee
        uint256 messengerDstGasInNative = HALF_DST_GAS * s_lastGasPrices[dstChainSelector];
        uint256 messengerSrcGasInNative = HALF_DST_GAS * s_lastGasPrices[CHAIN_SELECTOR];
        uint256 messengerGasFeeInUsdc = ((messengerDstGasInNative + messengerSrcGasInNative) *
            s_latestNativeUsdcRate) / STANDARD_TOKEN_DECIMALS;

        return (functionsFeeInUsdc + CCIP_FEE_IN_USDC + conceroFee + messengerGasFeeInUsdc);
    }
}
