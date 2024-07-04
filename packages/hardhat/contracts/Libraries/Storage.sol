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
///@notice error emitted when a non-messenger address call a controlled function
error Storage_NotMessenger(address caller);

abstract contract Storage is IStorage {
  ///////////////
  ///IMMUTABLE///
  ///////////////
  address internal immutable i_owner;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 internal constant APPROVED = 1;
  uint256 private constant USDC_DECIMALS = 10 ** 6;
  uint256 private constant STANDARD_TOKEN_DECIMALS = 10 ** 18;

  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
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

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event Storage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when the Messenger address is updated
  event Storage_MessengerUpdated(address indexed walletAddress, uint256 status);
  ///@notice event emitted when the router address is approved
  event Storage_NewRouterAdded(address router, uint256 isAllowed);

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (isMessenger(msg.sender) == false) revert Storage_NotMessenger(msg.sender);
    _;
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////
  constructor(address _initialOwner) {
    i_owner = _initialOwner;
  }

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
  function getToken(CCIPToken token, Chain _chainIndex) internal view returns (address) {
    address[4][2] memory tokens;

    // Initialize BNM addresses
    tokens[uint(CCIPToken.bnm)][uint(Chain.arb)] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[uint(CCIPToken.bnm)][uint(Chain.base)] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[uint(CCIPToken.bnm)][uint(Chain.opt)] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt
    tokens[uint(CCIPToken.bnm)][uint(Chain.pol)] = 0xcab0EF91Bee323d1A617c0a027eE753aFd6997E4; // pol

    // Initialize USDC addresses
    tokens[uint(CCIPToken.usdc)][uint(Chain.arb)] = block.chainid == 42161 ? USDC_ARBITRUM : 	0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    tokens[uint(CCIPToken.usdc)][uint(Chain.base)] = block.chainid == 8453 ? USDC_BASE : 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    tokens[uint(CCIPToken.usdc)][uint(Chain.opt)] = USDC_OPTIMISM;
    tokens[uint(CCIPToken.usdc)][uint(Chain.pol)] = USDC_POLYGON;

    if (uint256(token) > tokens.length) revert Storage_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) > tokens[uint256(token)].length) revert Storage_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }

  /**
   * @notice Internal function to convert USDC Decimals to LP Decimals
   * @param _amount the amount of USDC
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToUSDCDecimals(uint256 _amount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_amount * USDC_DECIMALS) / STANDARD_TOKEN_DECIMALS;
  }

  /**
   * @notice Function to check if a caller address is an allowed messenger
   * @param _messenger the address of the caller
   */
  function isMessenger(address _messenger) internal pure returns (bool _isMessenger) {
    address[] memory messengers = new address[](4); //Number of messengers. To define.
    messengers[0] = 0x05CF0be5cAE993b4d7B70D691e063f1E0abeD267; //fake messenger from foundry environment
    messengers[1] = address(0);
    messengers[2] = address(0);
    messengers[3] = address(0);

    for (uint256 i; i < messengers.length; ) {
      if (_messenger == messengers[i]) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }
}
