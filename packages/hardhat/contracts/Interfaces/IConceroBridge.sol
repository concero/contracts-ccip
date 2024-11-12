// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IInfraOrchestrator} from "./IInfraOrchestrator.sol";
import {IDexSwap} from "./IDexSwap.sol";
import {IInfraStorage} from "./IInfraStorage.sol";

interface IConceroBridge is IInfraStorage {
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
     * @param tokenType the token type
     * @param dstChainSelector the destination chain selector
     * @param amount the amount to be bridged
     * @return the total fee in USDC
     */
    function getSrcTotalFeeInUSDC(
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);
}
