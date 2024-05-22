// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

interface IConceroCommon {
  event ConceroCommon_ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  event ConceroCommon_MessengerUpdated(address indexed walletAddress, bool status);

  error TransferFailed(); //@audit not being used
  error InsufficientFee(); //@audit not being used
  error ConceroCommon_InvalidAddress();
  error ConceroCommon_AddressAlreadyAllowlisted();
  error ConceroCommon_NotAllowlistedOrAlreadyRemoved();
  error ConceroCommon_TokenTypeOutOfBounds();
  error ConceroCommon_ChainIndexOutOfBounds();

  error Concero_InsufficientFundsForFees(uint256 amount, uint256 fee);

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
  error ConceroCCIP_ChainNotAllowed(uint64 ChainSelector);
  error ConceroCCIP_SourceChainNotAllowed(uint64 sourceChainSelector);
  error ConceroCCIP_SenderNotAllowed(address sender);
  error ConceroCCIP_InvalidReceiverAddress();
  error ConceroCCIP_InsufficientBalance();
  error ConceroCCIP_NotEnoughLinkBalance(uint256 fees, uint256 feeToken);

  error Concero_NothingToWithdraw();
  error Concero_FailedToWithdrawEth(address owner, address target, uint256 value);
  error NotFunctionContract(address sender); //@audit not being used

  event Concero_CCIPSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    CCIPToken token,
    uint256 amount,
    uint64 dstChainSelector
  );
  event Concero_CLFPremiumFeeUpdated(
    uint64 chainSelector,
    uint256 previousValue,
    uint256 feeAmount
  );
}

interface IFunctions is IConceroCommon {
  event ConceroFunctions_UnconfirmedTXAdded(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 srcChainSelector
  );
  event ConceroFunctions_UnconfirmedTXSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 dstChainSelector
  );
  event ConceroFunctions_TXConfirmed(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    uint256 amount,
    CCIPToken token
  );
  event ConceroFunctions_TXReleased(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    address token,
    uint256 amount
  );
  event ConceroFunctions_TXReleaseFailed( //@audit we can remove this or is being tracked somewhere else?
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    address token,
    uint256 amount
  );
  event ConceroFunctions_FunctionsRequestError(bytes32 indexed ccipMessageId, bytes32 requestId, uint8 requestType);
  event ConceroFunctions_ConceroPoolAddressUpdated(address previousAddress, address pool);
  event ConceroFunctions_DonSecretVersionUpdated(uint64 previousDonSecretVersion, uint64 newDonSecretVersion);
  event ConceroFunctions_DonSlotIdUpdated(uint8 previousDonSlot, uint8 newDonSlot); 
  event ConceroFunctions_DestinationJsHashSumUpdated(bytes32 previousDstHashSum, bytes32 newDstHashSum);
  event ConceroFunctions_SourceJsHashSumUpdated(bytes32 previousSrcHashSum, bytes32 newSrcHashSum);

  error ConceroFunctions_NotMessenger(address);
  error ConceroFunctions_TXAlreadyExists(bytes32 txHash, bool isConfirmed);
  error ConceroFunctions_UnexpectedRequestID(bytes32);
  error NotCCIPContract(address); //@audit not being used
  error ConceroFunctions_SendTokenFailed(bytes32 ccipMessageId, address token, uint256 amount, address recipient);//@audit we can remove this or is being tracked somewhere else?

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
