// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

interface IFunctions{
  event TXReleased(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    address token,
    uint256 amount
  ); //@audit unused
  event TXReleaseFailed(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    address token,
    uint256 amount
  ); //@audit we can remove this or is being tracked somewhere else?

  //  error NotCCIPContract(address); //@audit not being used
  //  error SendTokenFailed(bytes32 ccipMessageId, address token, uint256 amount, address recipient); //@audit we can remove this or is being tracked somewhere else?
  
}