// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IDexSwap} from "./IDexSwap.sol";
import {IStorage} from "./IStorage.sol";

interface IConceroBridge is IStorage {
    function startBridge(
        BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData,
        address ccipFeeToken
    ) external payable;

    function getSrcTotalFeeInUSDC(
        CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount,
        address ccipFeeToken
    ) external view returns (uint256);
}
