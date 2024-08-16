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
    uint8 internal constant MAX_PENDING_CCIP_TRANSACTIONS = 5;

    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////
    /// @notice event emitted when a CCIP message is sent
    event CCIPSent(
        bytes32 indexed ccipMessageId,
        address sender,
        address recipient,
        CCIPToken token,
        uint256 amount,
        uint64 dstChainSelector
    );
    /// @notice event emitted when a stuck amount is withdraw
    event Concero_StuckAmountWithdraw(address owner, address token, uint256 amount);

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
        uint256 lpFee = getDstTotalFeeInUsdc(amountToSend);

        bytes32 batchedTxId = keccak256(
            abi.encodePacked(
                msg.sender,
                bridgeData.receiver,
                amountToSend,
                block.timestamp,
                block.prevrandao
            )
        );

        BridgeTx memory newBridgeTx = BridgeTx(bridgeData.receiver, amountToSend, batchedTxId);

        s_pendingCCIPTransactionsByDstChain[bridgeData.dstChainSelector].push(batchedTxId);
        s_pendingCCIPTransactions[batchedTxId] = newBridgeTx;

        bytes32[] memory pendingCCIPTransactionsByDstChain = s_pendingCCIPTransactionsByDstChain[
            bridgeData.dstChainSelector
        ];

        if (pendingCCIPTransactionsByDstChain.length >= MAX_PENDING_CCIP_TRANSACTIONS) {
            uint256 batchedAmountsToSend;
            BridgeTx[] memory bridgeTxs = new BridgeTx[](pendingCCIPTransactionsByDstChain.length);

            for (uint256 i; i < pendingCCIPTransactionsByDstChain.length; ++i) {
                bytes32 txId = pendingCCIPTransactionsByDstChain[i];
                BridgeTx memory bridgeTx = s_pendingCCIPTransactions[txId];

                batchedAmountsToSend += bridgeTx.amount;
                bridgeTxs[i] = bridgeTx;
            }

            delete s_pendingCCIPTransactionsByDstChain[bridgeData.dstChainSelector];

            bytes32 ccipMessageId = _sendTokenPayLink(
                bridgeData.dstChainSelector,
                fromToken,
                batchedAmountsToSend,
                bridgeTxs
            );
        }

        // TODO: for dstSwaps: add unique keccak id with all argument including dstSwapData
        //    bytes32 id = keccak256(abi.encodePacked(ccipMessageId, bridgeData, dstSwapData));
        emit CCIPSent(
            batchedTxId,
            msg.sender,
            bridgeData.receiver,
            bridgeData.tokenType,
            amountToSend,
            bridgeData.dstChainSelector
        );
        sendUnconfirmedTX(
            batchedTxId,
            msg.sender,
            bridgeData.receiver,
            amountToSend,
            bridgeData.dstChainSelector,
            bridgeData.tokenType,
            dstSwapData
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
    function getCCIPFeeInLink(uint64 _dstChainSelector) public view returns (uint256) {
        return s_lastCCIPFeeInLink[_dstChainSelector];
    }

    /**
     * @notice Function to get the total amount of CCIP fees in USDC
     * @param _dstChainSelector the destination blockchain chain selector
     */
    function getCCIPFeeInUsdc(uint64 _dstChainSelector) public view returns (uint256) {
        uint256 ccipFeeInLink = getCCIPFeeInLink(_dstChainSelector);
        return (ccipFeeInLink * uint256(s_latestLinkUsdcRate)) / STANDARD_TOKEN_DECIMALS;
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
        uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(dstChainSelector);
        ccipFeeInUsdc = ccipFeeInUsdc / MAX_PENDING_CCIP_TRANSACTIONS;

        // @notice concero fee
        uint256 conceroFee = amount / CONCERO_FEE_FACTOR;

        // @notice gas fee
        uint256 messengerDstGasInNative = HALF_DST_GAS * s_lastGasPrices[dstChainSelector];
        uint256 messengerSrcGasInNative = HALF_DST_GAS * s_lastGasPrices[CHAIN_SELECTOR];
        uint256 messengerGasFeeInUsdc = ((messengerDstGasInNative + messengerSrcGasInNative) *
            s_latestNativeUsdcRate) / STANDARD_TOKEN_DECIMALS;

        return (functionsFeeInUsdc + ccipFeeInUsdc + conceroFee + messengerGasFeeInUsdc);
    }

    function getSrcTotalFeeInUSDC(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256) {
        return _getSrcTotalFeeInUsdc(dstChainSelector, amount);
    }
}
