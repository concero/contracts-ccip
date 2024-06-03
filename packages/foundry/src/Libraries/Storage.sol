//SPDX-License-Identificer: MIT
pragma solidity 0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/upgradeable/contracts/access/OwnableUpgradeable.sol";

import {IDexSwap} from "../Interfaces/IDexSwap.sol";

  ////////////////////////////////////////////////////////
  //////////////////////// ERRORS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice error emitted when bridge data is empty
  error Storage_InvalidBridgeData();
  ///@notice error emited when the choosen token is not allowed
  error Storage_TokenTypeOutOfBounds();
  ///@notice error emitted when the chain index is incorrect
  error Storage_ChainIndexOutOfBounds();
  ///@notice error emitted when the caller is not the messenger
  error Storage_NotMessenger(address caller);
  ///@notice error emitted when the input is the address(0)
  error Storage_InvalidAddress();
  ///@notice error emitted when the chain selector input is invalid
  error Storage_ChainNotAllowed(uint64 chainSelector);

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
  ///@notice CCIP Data to Bridge
  struct BridgeData {
    CCIPToken tokenType;
    uint256 amount;
    uint256 minAmount;
    uint64 dstChainSelector;
    address receiver;
  }
  ///@notice ConceroPool Request 
  struct WithdrawRequests {
    uint256 condition;
    uint256 amount;
    bool isActiv;
    bool isFulfilled;
  }
  ///@notice Functions Js Code
  struct JsCodeHashSum {
    bytes32 src;
    bytes32 dst;
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
  ///@notice Chainlink Price Feeds
  struct PriceFeeds {
    address linkToUsdPriceFeeds;
    address usdcToUsdPriceFeeds;
    address nativeToUsdPriceFeeds;
    address linkToNativePriceFeeds;
  }

  ///////////////
  ///VARIABLES///
  ///////////////
  ///@notice Orchestrato: variable to store the Orchestrator address
  address internal s_orchestratorImplementation;
  ///@notice The address of messenger wallet who performs specific calls
  address internal s_messenger;
  ///@notice DexSwap: variable to store the DexSwap address
  address internal s_dexSwap;
  ///@notice variable to store the Orchestrator Proxy Address
  address internal s_orchestrator;
  ///@notice variable to store the Concero address
  address internal s_concero;
  ///@notice variable to store the ConceroPool address
  address internal s_pool;
  ///@notice ID of the deployed chain on getChain() function
  Chain internal s_chainIndex;
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 internal s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source JS Code
  bytes32 internal s_srcJsHashSum;
  ///@notice variable to store the Chainlink Function Destination JS Code
  bytes32 internal s_dstJsHashSum;
  ///@notice gap to reserve storage in the contract for future variable additions
  uint256[50] __gap;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice Concero: Mapping to keep track of CLF fees for different chains
  mapping(uint64 => uint256) public clfPremiumFees;
  
  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) internal s_messengerContracts;
  ///@notice DexSwap: mapping to keep track of allowed routers to perform swaps. 1 == Allowed.
  mapping(address router => uint256 isAllowed) internal s_routerAllowed;

  ///@notice ConceroPool: Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolReceiver;
  ///@notice ConceroPool: Mapping to keep track of allowed tokens
  mapping(address token => uint256 isApproved) public s_isTokenSupported;
  ///@notice ConceroPool: Mapping to keep track of allowed senders on a given token
  mapping(address token => address senderAllowed) public s_approvedSenders;
  ///@notice ConceroPool: Mapping to keep track of balances of user on a given token
  mapping(address token => mapping(address user => uint256 balance)) public s_userBalances;
  ///@notice ConceroPool: Mapping to keep track of allowed pool senders
  mapping(uint64 chainId => mapping(address poolAddress => uint256)) public s_allowedPool;
  ///@notice ConceroPool: Mapping to keep track of withdraw requests
  mapping(address token => WithdrawRequests) internal s_withdrawWaitlist;

  ///@notice Functions: Mapping to keep track of Concero.sol contracts to send cross-chain Chainlink Functions messages
  mapping(uint64 chainSelector => address conceroContract) internal s_conceroContracts;
  ///@notice Functions: Mapping to keep track of cross-chain transactions
  mapping(bytes32 => Transaction) public s_transactions;
  ///@notice Functions: Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 => Request) public s_requests;
  ///@notice Functions: Mapping to keep track of cross-chain gas prices
  mapping(uint64 chainSelector => uint256 lasGasPrice) public s_lastGasPrices;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event Storage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a Concero contract is added
  event Storage_srcConceroContractUpdated(address previousAddress, address newConceroAddress);
  ///@notice event emitted when the Messenger address is updated
  event Storage_MessengerUpdated(address indexed walletAddress, uint256 status);

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

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (s_messengerContracts[msg.sender] != APPROVED) revert Storage_NotMessenger(msg.sender);
    _;
  }

  /**
   * @notice CCIP Modifier to check receivers for a specific chain
   * @param _chainSelector Id of the destination chain
   */
  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_poolReceiver[_chainSelector] == address(0)) revert Storage_ChainNotAllowed(_chainSelector);
    _;
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////

  //////////////
  ///EXTERNAL///
  //////////////

  /**
   * @notice function to manage the Concero contract address
   * @param _concero the address from the Concero Contract
   * @dev only owner can call it
   * @dev it's payable to save some gas.
  */
  function setConceroContract(address _concero) external payable onlyOwner{
    address previousAddress = s_concero;

    s_concero = _concero;

    emit Storage_srcConceroContractUpdated(previousAddress, _concero);
  }

  /**
   * @notice Function to update Concero Messenger Addresses
   * @param _walletAddress the messenger address
   * @param _approved 1 == Approved | Any other value disapproved
   */
  //@changed
  function setConceroMessenger(address _walletAddress, uint256 _approved) external onlyOwner {
    if (_walletAddress == address(0)) revert Storage_InvalidAddress();

    s_messengerContracts[_walletAddress] = _approved;
    s_messenger = _walletAddress;

    emit Storage_MessengerUpdated(_walletAddress, _approved);
  }

  /////////////////
  ///VIEW & PURE///
  /////////////////
  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
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