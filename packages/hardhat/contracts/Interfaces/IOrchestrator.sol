// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStorage} from "./IStorage.sol";

interface IOrchestrator {
  function getTransactionsInfo(bytes32 _ccipMessageId) external view returns (IStorage.Transaction memory transaction);
}

interface IOrchestratorViewDelegate {
  function getSrcTotalFeeInUsdcViaDelegateCall(IStorage.CCIPToken tokenType, uint64 dstChainSelector, uint256 amount) external view returns (uint256);
}
