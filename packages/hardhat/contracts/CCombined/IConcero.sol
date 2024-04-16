// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

interface ICCIP {
  error DestinationChainNotAllowed(uint64 _dstChainSelector);
  error InvalidReceiverAddress();
  error NotEnoughBalance(uint256 _fees, uint256 _feeToken);
  error SourceChainNotAllowed(uint64 _sourceChainSelector);
  error SenderNotAllowed(address _sender);
  error NothingToWithdraw();
  error FailedToWithdrawEth(address owner, address target, uint256 value);
  error NotFunctionContract(address _sender);

  event CCIPSent(bytes32 indexed ccipMessageId, address sender, address recipient, address token, uint256 amount, uint64 dstChainSelector);
  event CCIPReceived(bytes32 indexed ccipMessageId, uint64 srcChainSelector, address sender, address receiver, address token, uint256 amount);
  event TXReleased(bytes32 indexed ccipMessageId, address indexed sender, address indexed recipient, address token, uint256 amount);
}

interface IFunctions {
  event UnconfirmedTXAdded(bytes32 indexed ccipMessageId, address sender, address recipient, uint256 amount, address token, uint64 srcChainSelector);
  event UnconfirmedTXSent(bytes32 indexed ccipMessageId, address sender, address recipient, uint256 amount, address token, uint64 dstChainSelector);
  event TXConfirmed(bytes32 indexed ccipMessageId, address indexed sender, address indexed recipient, uint256 amount, address token);
  event AllowlistUpdated(address indexed walletAddress, bool status);

  error NotAllowed();
  error TXAlreadyExists(bytes32 txHash, bool isConfirmed);
  error UnexpectedRequestID(bytes32);
  error NotCCIPContract(address);

  struct Transaction {
    bytes32 ccipMessageId;
    address sender;
    address recipient;
    uint256 amount;
    address token;
    uint64 srcChainSelector;
    bool isConfirmed;
  }

  enum RequestType {
    addUnconfirmedTxDst,
    checkTxSrc
  }

  struct Request {
    RequestType requestType;
    bool isPending;
  }
}
