//SPDX-License-Identificer: MIT
pragma solidity 0.8.20;

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStorage} from "../Interfaces/IStorage.sol";
import {ConceroCCIP} from "../ConceroCCIP.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when bridge data is empty
error Storage_InvalidBridgeData();
///@notice error emited when the choosen token is not allowed
error Storage_TokenTypeOutOfBounds();
///@notice error emitted when the chain index is incorrect
error Storage_ChainIndexOutOfBounds();

abstract contract Storage is IStorage {
  address internal immutable i_owner;

  constructor(address _initialOwner) {
    i_owner = _initialOwner;
  }

  ///////////////
  ///VARIABLES///
  ///////////////

  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 internal s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 internal s_srcJsHashSum;
  ///@notice variable to store the Chainlink Function Destination Hashsum
  bytes32 internal s_dstJsHashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 internal s_ethersHashSum;
  ///@notice Variable to store the Link to USDC latest rate
  uint256 public s_latestLinkUsdcRate;
  ///@notice Variable to store the Native to USDC latest rate
  uint256 public s_latestNativeUsdcRate;
  ///@notice Variable to store the Link to Native latest rate
  uint256 public s_latestLinkNativeRate;
  ///@notice gap to reserve storage in the contract for future variable additions
  uint256[50] __gap;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  Pools[] poolsToDistribute;

  ///@notice Concero: Mapping to keep track of CLF fees for different chains
  mapping(uint64 => uint256) public clfPremiumFees;
  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) internal s_messengerContracts;
  ///@notice DexSwap: mapping to keep track of allowed routers to perform swaps. 1 == Allowed.
  mapping(address router => uint256 isAllowed) internal s_routerAllowed;
  ///@notice ConceroPool a: Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolReceiver;
  ///@notice ConceroPool: Mapping to keep track of allowed tokens
  mapping(address token => uint256 isApproved) public s_isTokenSupported;
  ///@notice ConceroPool: Mapping to keep track of allowed senders on a given token
  mapping(address token => address senderAllowed) public s_approvedSenders;
  ///@notice ConceroPool: Mapping to keep track of balances of user on a given token
  mapping(address token => mapping(address user => uint256 balance)) public s_userBalances;
  ///@notice ConceroPool: Mapping to keep track of allowed pool senders
  mapping(uint64 chainSelector => mapping(address poolAddress => uint256)) public s_allowedPool;
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

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;
  ///@notice Removing magic numbers from calculations
  uint16 internal constant CONCERO_FEE_FACTOR = 1000;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event Storage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when the Messenger address is updated
  event Storage_MessengerUpdated(address indexed walletAddress, uint256 status);
  ///@notice event emitted when the router address is approved
  event Storage_NewRouterAdded(address router, uint256 isAllowed);

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////

  /////////////////
  ///VIEW & PURE///
  /////////////////

  address private constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
  address private constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  address private constant USDC_OPTIMISM = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
  function getToken(CCIPToken token, Chain _chainIndex) internal pure returns (address) {
    address[3][2] memory tokens;

    //@audit use the actual chain id and not 0 1 2
    // Initialize BNM addresses
    //    tokens[0][0] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    //    tokens[0][1] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    //    tokens[0][2] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt

    // Initialize USDC addresses
    tokens[uint(CCIPToken.usdc)][uint(Chain.arb)] = USDC_ARBITRUM; // arb
    tokens[uint(CCIPToken.usdc)][uint(Chain.base)] = USDC_BASE; // base
    tokens[uint(CCIPToken.usdc)][uint(Chain.opt)] = USDC_OPTIMISM; // opt

    if (uint256(token) > tokens.length) revert Storage_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) > tokens[uint256(token)].length) revert Storage_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }
}
