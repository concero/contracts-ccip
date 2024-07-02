//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IDexSwap} from "../Interfaces/IDexSwap.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStorage} from "../Interfaces/IStorage.sol";
import {ConceroCCIP} from "../ConceroCCIP.sol";
import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON} from "../Constants.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when bridge data is empty
error Storage_InvalidBridgeData();
///@notice error emitted when the chosen token is not allowed
error Storage_TokenTypeOutOfBounds();
///@notice error emitted when the chain index is incorrect
error Storage_ChainIndexOutOfBounds();
///@notice error emitted when a not allowed caller try to get CCIP information from storage
error Storage_CallerNotAllowed();

abstract contract Storage is IStorage {
  address internal immutable i_owner;

  constructor(address _initialOwner) {
    i_owner = _initialOwner;
  }

  ///////////////
  ///VARIABLES///
  ///////////////

  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 public s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 public s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 public s_srcJsHashSum;
  ///@notice variable to store the Chainlink Function Destination Hashsum
  bytes32 public s_dstJsHashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 public s_ethersHashSum;
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
  ///@notice DexSwap: mapping to keep track of allowed routers to perform swaps. 1 == Allowed.
  mapping(address router => uint256 isAllowed) public s_routerAllowed;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolReceiver;
  ///@notice Functions: Mapping to keep track of Concero.sol contracts to send cross-chain Chainlink Functions messages
  mapping(uint64 chainSelector => address conceroContract) public s_conceroContracts;
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
  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
  function getToken(CCIPToken token, Chain _chainIndex) internal pure returns (address) {
    address[4][2] memory tokens;

    // Initialize BNM addresses
    tokens[uint(CCIPToken.bnm)][uint(Chain.arb)] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[uint(CCIPToken.bnm)][uint(Chain.base)] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[uint(CCIPToken.bnm)][uint(Chain.opt)] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt
    tokens[uint(CCIPToken.bnm)][uint(Chain.pol)] = 0xcab0EF91Bee323d1A617c0a027eE753aFd6997E4; // pol

    // Initialize USDC addresses
    tokens[uint(CCIPToken.usdc)][uint(Chain.arb)] = USDC_ARBITRUM;
    tokens[uint(CCIPToken.usdc)][uint(Chain.base)] = USDC_BASE;
    tokens[uint(CCIPToken.usdc)][uint(Chain.opt)] = USDC_OPTIMISM;
    tokens[uint(CCIPToken.usdc)][uint(Chain.pol)] = USDC_POLYGON;

    if (uint256(token) > tokens.length) revert Storage_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) > tokens[uint256(token)].length) revert Storage_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }
}
