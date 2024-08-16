// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IStorage} from "./IStorage.sol";
import "./IDexSwap.sol";

interface IOrchestrator {
    function swap(IDexSwap.SwapData[] calldata _swapData, address _receiver) external payable;

    function bridge(
        IStorage.BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable;

    function swapAndBridge(
        IStorage.BridgeData memory bridgeData,
        IDexSwap.SwapData[] calldata srcSwapData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable;

    function getTransaction(
        bytes32 _ccipMessageId
    ) external view returns (IStorage.Transaction memory transaction);
}

interface IOrchestratorViewDelegate {
    function getSrcTotalFeeInUSDCViaDelegateCall(
        IStorage.CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);
}
