// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

interface IConceroCommon {
  event ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  event MessengerUpdated(address indexed walletAddress, bool status);

  error InvalidAddress();
  error AddressAlreadyAllowlisted();
  error NotAllowlistedOrAlreadyRemoved();
  error TokenTypeOutOfBounds();
  error ChainIndexOutOfBounds();
  error Concero_FoTNotAllowedYet();

  error InsufficientFundsForFees(uint256 amount, uint256 fee);
  error FundsLost(address token, uint256 balanceBefore, uint256 balanceAfter, uint256 amount);
  error InvalidAmount();
}

interface ICCIP is IConceroCommon {
  error ChainNotAllowed(uint64 ChainSelector);
  error SourceChainNotAllowed(uint64 sourceChainSelector);
  error SenderNotAllowed(address sender);
  error InvalidReceiverAddress();
  error NotEnoughLinkBalance(uint256 fees, uint256 feeToken);

  error NothingToWithdraw();
  error FailedToWithdrawEth(address owner, address target, uint256 value);
  error InvalidBridgeData();

  event CCIPSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint8 token,
    uint256 amount,
    uint64 dstChainSelector
  );
  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);

}

interface IFunctions is IConceroCommon {
  event UnconfirmedTXAdded(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    uint8 token,
    uint64 srcChainSelector
  );
  event UnconfirmedTXSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    uint8 token,
    uint64 dstChainSelector
  );
  event TXConfirmed(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    uint256 amount,
    uint8 token
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
}