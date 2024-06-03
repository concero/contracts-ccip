// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IDexSwap} from "./IDexSwap.sol";

interface IConcero{
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////

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
    
  function startBridge(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata dstSwapData) external;
}