//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
import {IStorage} from "./IStorage.sol";

interface IOrchestrator is IStorage {
  function swapAndBridge(
    BridgeData calldata _bridgeData,
    IDexSwap.SwapData[] calldata _srcSwapData,
    IDexSwap.SwapData[] calldata _dstSwapData
  ) external payable;

  function swap(IDexSwap.SwapData[] calldata _swapData) external payable;

  function bridge(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata dstSwapData) external payable;
}
