// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IStorage} from "./IStorage.sol";

interface IOrchestrator {
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
