//SPDX-License-Identificer: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/upgradeable/contracts/access/OwnableUpgradeable.sol";

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
import {LibConcero} from "../Libraries/LibConcero.sol";


abstract contract Storage is OwnableUpgradeable{
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  ///@notice Chainlink Functions Request Type
  enum RequestType {
    addUnconfirmedTxDst,
    checkTxSrc
  }
  ///@notice CCIP Compatible Tokens
  enum CCIPToken {
    bnm,
    usdc
  }
  ///@notice Operational Chains
  enum Chain {
    arb,
    base,
    opt
  }
  ///@notice Function Request
  struct Request {
    RequestType requestType;
    bool isPending;
    bytes32 ccipMessageId;
  }
  ///@notice Chainlink Price Feeds
  struct PriceFeeds {
    address linkToUsdPriceFeeds;
    address usdcToUsdPriceFeeds;
    address nativeToUsdPriceFeeds;
    address linkToNativePriceFeeds;
  }
  ///@notice Functions Js Code
  struct JsCodeHashSum {
    bytes32 src;
    bytes32 dst;
  }
  ///@notice ConceroPool Request 
  struct WithdrawRequests {
    uint256 condition;
    uint256 amount;
    bool isActiv;
    bool isFulfilled;
  }
  ///@notice Chainlink Functions Transaction
  struct Transaction {
    bytes32 ccipMessageId;
    address sender;
    address recipient;
    uint256 amount;
    CCIPToken token;
    uint64 srcChainSelector;
    bool isConfirmed;
  }
  ///@notice CCIP Data to Bridge
  struct BridgeData {
    CCIPToken tokenType;
    uint256 amount;
    uint256 minAmount;
    uint64 dstChainSelector;
    address receiver;
  }

  /////////////
  ///STORAGE///
  /////////////
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolReceiver;
  //@audit I think this can be a common variable.
  //Need to check if will be more than one address
  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => bool allowed) internal s_messengerContracts;

  ///////////////
  ///VARIABLES///
  ///////////////

  //Functions
  ///@notice ID of the deployed chain on getChain() function
  Chain internal s_chainIndex;
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  //Storage
  ///@notice event emitted when a Concero pool is added
  event Storage_PoolReceiverUpdated(uint64 chainSelector, address pool);

  //Concero Common
  ///@notice event emitted when the Messenger address is updated
  event MessengerUpdated(address indexed walletAddress, bool status);
  //Moved to Functions
  ///@notice event emitted when the address for the Concero Contract is updated
  event ConceroContractUpdated(uint64 chainSelector, address conceroContract);
  
  //ICCIP
  ///@notice event emitted when a CCIP message is sent
  event CCIPSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    CCIPToken token,
    uint256 amount,
    uint64 dstChainSelector
  );
  ///@notice event emitted when the Chainlink Function Fee is updated
  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);
  
  //IFunctions
  ///@notice emitted on source when a Unconfirmed TX is sent
  event UnconfirmedTXSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 dstChainSelector
  );
  ///@notice emitted when a Unconfirmed TX is added by a cross-chain TX
  event UnconfirmedTXAdded(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    CCIPToken token,
    uint64 srcChainSelector
  );
  ///@notice emitted when on destination when a TX is validated.
  event TXConfirmed(
    bytes32 indexed ccipMessageId,
    address indexed sender,
    address indexed recipient,
    uint256 amount,
    CCIPToken token
  );
  ///@notice emitted when a Function Request returns an error
  event FunctionsRequestError(bytes32 indexed ccipMessageId, bytes32 requestId, uint8 requestType);
  ///@notice emitted when the concero pool address is updated
  event ConceroPoolAddressUpdated(address previousAddress, address pool);
  ///@notice emitted when the secret version of Chainlink Function Don is updated
  event DonSecretVersionUpdated(uint64 previousDonSecretVersion, uint64 newDonSecretVersion);
  ///@notice emitted when the slot ID of Chainlink Function is updated
  event DonSlotIdUpdated(uint8 previousDonSlot, uint8 newDonSlot);
  ///@notice emitted when the source JS code of Chainlink Function is updated
  event SourceJsHashSumUpdated(bytes32 previousSrcHashSum, bytes32 newSrcHashSum);
  ///@notice emitted when the destination JS code of Chainlink Function is updated
  event DestinationJsHashSumUpdated(bytes32 previousDstHashSum, bytes32 newDstHashSum);

  ////////////////////////////////////////////////////////
  //////////////////////// ERRORS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice error emitted when bridge data is empty
  error Storage_InvalidBridgeData();
  ///@notice error emited when the amount sent if bigger than the specified param
  error Storage_InvalidAmount();
  ///@notice error emited when the choosen token is not allowed
  error Storage_TokenTypeOutOfBounds();
  ///@notice error emitted when the chain index is incorrect
  error Storage_ChainIndexOutOfBounds();

  //IConceroCommon
  ///@notice error emitted when the Messenger receive an address(0)
  error InvalidAddress();
  ///@notice error emitted when the Messenger were set already
  error AddressAlreadyAllowlisted();
  ///@notice error emitted when the Concero Messenger have been removed already
  error NotAllowlistedOrAlreadyRemoved();
  ///@notice error emitted when the token to be swaped has fee on transfers
  error Concero_FoTNotAllowedYet();
  ///@notice error emitted when the input amount is less than the fees
  error InsufficientFundsForFees(uint256 amount, uint256 fee);

  //ICCIP
  ///@notice error emitted when the destination chain is not allowed
  error ChainNotAllowed(uint64 ChainSelector);
  ///@notice error emitted when the source chain is not allowed
  error SourceChainNotAllowed(uint64 sourceChainSelector);
  ///@notice error emitted when the sender of the message is not allowed
  error SenderNotAllowed(address sender);
  ///@notice error emitted when the receiver address is invalid
  error InvalidReceiverAddress();
  ///@notice error emitted when the link balance is not enough to send the message
  error NotEnoughLinkBalance(uint256 fees, uint256 feeToken);
  ///@notice error emitted when there is no ERC20 value to withdraw
  error NothingToWithdraw();
  ///@notice error emitted when there is no native value to withdraw
  error FailedToWithdrawEth(address owner, address target, uint256 value);

  //IFunctions
  ///@notice error emitted when the caller is not the messenger
  error NotMessenger(address caller);
  ///@notice error emitted when a TX was already added
  error TXAlreadyExists(bytes32 txHash, bool isConfirmed);
  ///@notice error emitted when a unexpected ID is added
  error UnexpectedRequestID(bytes32);
  ///@notice error emitted when a transaction does not exist
  error TxDoesNotExist();
  ///@notice error emitted when a transaction was already confirmed
  error TxAlreadyConfirmed();
  ///@notice error emitted when function receive a call from a not allowed address
  error AddressNotSet();

  ///////////////
  ///MODIFIERS///
  ///////////////
  //@audit Unused in the moment
  modifier validateSwapAndBridgeData(BridgeData calldata _bridgeData, IDexSwap.SwapData[] calldata _srcSwapData, uint64 _chainIndex) {
    address swapDataToToken = _srcSwapData[_srcSwapData.length - 1].toToken;

    if (swapDataToToken == getToken(_bridgeData.tokenType, s_chainIndex)) {
      revert Storage_InvalidBridgeData();
    }
    _;
  }

  modifier onlyMessenger() {
    if (!s_messengerContracts[msg.sender]) revert NotMessenger(msg.sender);
    _;
  }

  /**
   * @notice CCIP Modifier to check receivers for a specific chain
   * @param _chainSelector Id of the destination chain
   */
  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_poolReceiver[_chainSelector] == address(0)) revert ChainNotAllowed(_chainSelector);
    _;
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////

  //////////////
  ///EXTERNAL///
  //////////////
  /**
   * @notice function to manage the Cross-chains Concero contracts
   * @param _chainSelector chain identifications
   * @param _pool address of the Cross-chains Concero contracts
   * @dev only owner can call it
   * @dev it's payable to save some gas.
  */
  function setConceroPoolReceiver(uint64 _chainSelector, address _pool) external payable onlyOwner{
    s_poolReceiver[_chainSelector] = _pool;

    emit Storage_PoolReceiverUpdated(_chainSelector, _pool);
  }

  function setConceroMessenger(address _walletAddress) external onlyOwner {
    if (_walletAddress == address(0)) revert InvalidAddress();
    if (s_messengerContracts[_walletAddress] == true) revert AddressAlreadyAllowlisted();

    s_messengerContracts[_walletAddress] = true;

    emit MessengerUpdated(_walletAddress, true);
  }

  //@audit we can merge setConceroMessenger & removeConceroMessenger
  function removeConceroMessenger(address _walletAddress) external onlyOwner {
    if (_walletAddress == address(0)) revert InvalidAddress();
    if (s_messengerContracts[_walletAddress] == false) revert NotAllowlistedOrAlreadyRemoved();

    s_messengerContracts[_walletAddress] = false;

    emit MessengerUpdated(_walletAddress, true);
  }

  /////////////////
  ///VIEW & PURE///
  /////////////////
  function getToken(CCIPToken token, Chain _chainIndex) internal pure returns (address) {
    address[3][2] memory tokens;

    // Initialize BNM addresses
    tokens[0][0] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[0][1] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[0][2] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt

    // Initialize USDC addresses
    tokens[1][0] = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // arb
    tokens[1][1] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // base
    tokens[1][2] = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7; // opt

    if (uint256(token) > tokens.length) revert Storage_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) > tokens[uint256(token)].length) revert Storage_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }
}