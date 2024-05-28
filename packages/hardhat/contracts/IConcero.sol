// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

interface IConceroCommon {
  event ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  event MessengerUpdated(address indexed walletAddress, bool status);

  //  error TransferFailed(); //@audit not being used
  //  error InsufficientFee(); //@audit not being used
  error InvalidAddress();
  error AddressAlreadyAllowlisted();
  error NotAllowlistedOrAlreadyRemoved();
  error TokenTypeOutOfBounds();
  error ChainIndexOutOfBounds();

  error InsufficientFundsForFees(uint256 amount, uint256 fee);
  error FundsLost(address token, uint256 balanceBefore, uint256 balanceAfter, uint256 amount);
  error InvalidAmount();

  enum CCIPToken {
    bnm,
    usdc
  }

  enum Chain {
    arb,
    base,
    opt
  }
}

interface ICCIP is IConceroCommon {
  error ChainNotAllowed(uint64 ChainSelector);
  error SourceChainNotAllowed(uint64 sourceChainSelector);
  error SenderNotAllowed(address sender);
  error InvalidReceiverAddress();
  //  error InsufficientBalance(); // no usages
  error NotEnoughLinkBalance(uint256 fees, uint256 feeToken);

  error NothingToWithdraw();
  error FailedToWithdrawEth(address owner, address target, uint256 value);
  //  error NotFunctionContract(address _sender); //@audit not being used
  error InvalidBridgeData();

  event CCIPSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    CCIPToken token,
    uint256 amount,
    uint64 dstChainSelector
  );
  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);

  struct BridgeData {
    CCIPToken tokenType;
    uint256 amount;
    uint256 minAmount;
    uint64 dstChainSelector;
    address receiver;
  }
}

interface IFunctions is IConceroCommon {
  event UnconfirmedTXAdded(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 srcChainSelector
  );
  event UnconfirmedTXSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 dstChainSelector
  );
  event TXConfirmed(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    uint256 amount,
    CCIPToken token
  );
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

  event FunctionsRequestError(bytes32 indexed ccipMessageId, bytes32 requestId, uint8 requestType);
  event ConceroPoolAddressUpdated(address previousAddress, address pool);
  event DonSecretVersionUpdated(uint64 previousDonSecretVersion, uint64 newDonSecretVersion);
  event DonSlotIdUpdated(uint8 previousDonSlot, uint8 newDonSlot);
  event DestinationJsHashSumUpdated(bytes32 previousDstHashSum, bytes32 newDstHashSum);
  event SourceJsHashSumUpdated(bytes32 previousSrcHashSum, bytes32 newSrcHashSum);

  error NotMessenger(address);
  error TXAlreadyExists(bytes32 txHash, bool isConfirmed);
  error UnexpectedRequestID(bytes32);
  //  error NotCCIPContract(address); //@audit not being used
  //  error SendTokenFailed(bytes32 ccipMessageId, address token, uint256 amount, address recipient); //@audit we can remove this or is being tracked somewhere else?
  error TxDoesNotExist();
  error TxAlreadyConfirmed();
  error AddressNotSet();

  enum RequestType {
    addUnconfirmedTxDst,
    checkTxSrc
  }

  struct Request {
    RequestType requestType;
    bool isPending;
    bytes32 ccipMessageId;
  }

  struct Transaction {
    bytes32 ccipMessageId;
    address sender;
    address recipient;
    uint256 amount;
    CCIPToken token;
    uint64 srcChainSelector;
    bool isConfirmed;
  }
}
