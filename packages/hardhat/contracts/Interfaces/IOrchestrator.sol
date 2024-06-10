//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
interface IOrchestrator {

  ///@notice CCIP Compatible Tokens
  enum CCIPToken {
    bnm,
    usdc
  }

  ///@notice CCIP Data to Bridge
  struct BridgeData {
    CCIPToken tokenType;
    uint256 amount;
    uint256 minAmount;
    uint64 dstChainSelector;
    address receiver;
  }

  function swapAndBridge(BridgeData calldata _bridgeData, IDexSwap.SwapData[] calldata _srcSwapData, IDexSwap.SwapData[] calldata _dstSwapData) external payable;
  
  function swap(IDexSwap.SwapData[] calldata _swapData) external payable;
  
  function bridge(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata dstSwapData) external payable;
}