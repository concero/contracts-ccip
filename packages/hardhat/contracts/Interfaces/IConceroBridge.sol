// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IInfraOrchestrator} from "./IInfraOrchestrator.sol";
import {IDexSwap} from "./IDexSwap.sol";
import {IInfraStorage} from "./IInfraStorage.sol";

interface IConceroBridge is IInfraStorage {
    struct CcipSettlementTx {
        bytes32 id;
        uint256 amount;
        address recipient;
    }

    /// @notice event emitted when an individual tx is sent through CLF
    event ConceroBridgeSent(
        bytes32 indexed conceroMessageId,
        CCIPToken tokenType,
        uint256 amount,
        uint64 dstChainSelector,
        address receiver,
        bytes32 dstSwapDataHash
    );

    /// @notice event emitted when a batched CCIP message is sent
    event ConceroSettlementSent(bytes32 indexed ccipMessageId, uint256 amount);

    /**
     * @notice Function responsible to trigger CCIP and start the bridging process
     * @param bridgeData The bytes data payload with transaction infos
     * @param dstSwapData The bytes data payload with destination swap Data
     * @dev dstSwapData can be empty if there is no swap on destination
     * @dev this function should only be able to called thought infra Proxy
     */
    function bridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable;

    //todo: rename this function to getTotalBridgeFeeUSDC
    /**
     * @notice Function to get the total bridge fee in USDC
     * @param dstChainSelector the destination chain selector
     * @param amount the amount to be bridged
     * @return the total fee in USDC
     */
    function getSrcTotalFeeInUSDC(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);
}
