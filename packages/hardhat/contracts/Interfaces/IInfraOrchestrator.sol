// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IInfraStorage} from "./IInfraStorage.sol";
import "./IDexSwap.sol";

interface IInfraOrchestrator {
    function swap(
        IDexSwap.SwapData[] calldata _swapData,
        address _receiver,
        address _integrator,
        uint256 _integratorFeePercent
    ) external payable;

    function bridge(
        IInfraStorage.BridgeData memory bridgeData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable;

    function swapAndBridge(
        IInfraStorage.BridgeData memory bridgeData,
        IDexSwap.SwapData[] calldata srcSwapData,
        IDexSwap.SwapData[] memory dstSwapData
    ) external payable;

    function getTransaction(
        bytes32 _conceroBridgeTxId
    ) external view returns (IInfraStorage.Transaction memory transaction);
}

interface IOrchestratorViewDelegate {
    function getSrcTotalFeeInUSDCViaDelegateCall(
        IInfraStorage.CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);
}
