// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStorage} from "./IStorage.sol";

interface IOrchestrator {
  function getTransactionsInfo(bytes32 _ccipMessageId) external view returns (IStorage.Transaction memory transaction);
}
