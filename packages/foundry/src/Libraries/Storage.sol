//SPDX-License-Identificer: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ConceroPool} from "../ConceroPool.sol";
import {LibConcero} from "../Libraries/LibConcero.sol";

import {IDexSwap} from "../Interfaces/IDexSwap.sol";

error Storage_InvalidBridgeData();
error Storage_InvalidAmount();
error Storage_TokenTypeOutOfBounds();
error Storage_ChainIndexOutOfBounds();

abstract contract Storage {
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

  //1 == True
  ///@notice Mapping to keep track of allowed tokens
  mapping(address token => uint256 isApproved) public s_isTokenSupported;
  ///@notice Mapping to keep track of allowed senders on a given token
  mapping(address token => address senderAllowed) public s_approvedSenders;
  ///@notice Mapping to keep track of balances of user on a given token
  mapping(address token => mapping(address user => uint256 balance)) public s_userBalances;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainId => mapping(address poolAddress => uint256)) public s_allowedPool;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolReceiver;
  ///@notice Mapping to keep track of withdraw requests
  mapping(address token => WithdrawRequests) internal s_withdrawWaitlist;

  mapping(uint64 => uint256) public clfPremiumFees;
  mapping(uint64 chainSelector => address conceroContract) internal s_conceroContracts;
  mapping(address messenger => bool allowed) internal s_messengerContracts;
  mapping(bytes32 => Transaction) public s_transactions;
  mapping(bytes32 => Request) public s_requests;
  mapping(uint64 => uint256) public s_lastGasPrices; // chain selector => last gas price in wei

  ///////////////
  ///VARIABLES///
  ///////////////
  IDexSwap internal dexSwap;
  ConceroPool private s_pool;

  uint8 private s_donHostedSecretsSlotId;
  uint64 private s_donHostedSecretsVersion;

  bytes32 private s_srcJsHashSum;
  bytes32 private s_dstJsHashSum;

  address public s_conceroOrchestrator;
  address public s_messengerAddress;

  string private constant srcJsCode =
    "try { await import('npm:ethers@6.10.0'); const crypto = await import('node:crypto'); const hash = crypto.createHash('sha256').update(secrets.SRC_JS, 'utf8').digest('hex'); if ('0x' + hash.toLowerCase() === args[0].toLowerCase()) { return await eval(secrets.SRC_JS); } else { throw new Error(`0x${hash.toLowerCase()} != ${args[0].toLowerCase()}`); } } catch (err) { throw new Error(err.message.slice(0, 255));}";
  string private constant dstJsCode =
    "try { await import('npm:ethers@6.10.0'); const crypto = await import('node:crypto'); const hash = crypto.createHash('sha256').update(secrets.DST_JS, 'utf8').digest('hex'); if ('0x' + hash.toLowerCase() === args[0].toLowerCase()) { return await eval(secrets.DST_JS); } else { throw new Error(`0x${hash.toLowerCase()} != ${args[0].toLowerCase()}`); } } catch (err) { throw new Error(err.message.slice(0, 255));}";

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (LibConcero.isNativeToken(token)) {
      if (msg.value != amount) revert Storage_InvalidAmount();
    } else {
      uint256 balance = LibConcero.getBalance(token, msg.sender);
      if (balance < amount) revert Storage_InvalidAmount();
    }

    _;
  }

  modifier validateSwapAndBridgeData(BridgeData calldata _bridgeData, IDexSwap.SwapData[] calldata _srcSwapData, uint64 _chainIndex) {
    address swapDataToToken = _srcSwapData[_srcSwapData.length - 1].toToken;
    if (swapDataToToken == getToken(_bridgeData.tokenType, _chainIndex)) {
      revert Storage_InvalidBridgeData();
    }
    _;
  }

  modifier validateBridgeData(BridgeData calldata bridgeData) {
    if (bridgeData.amount > 0) {
      revert Storage_InvalidAmount();
    }
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] calldata swapData) {
    if (swapData.length > 0) {
      revert IDexSwap.InvalidSwapData();
    }

    if (LibConcero.isNativeToken(swapData[0].fromToken)) {
      if (swapData[0].fromAmount != msg.value) revert IDexSwap.InvalidSwapData();
    }
    _;
  }

  ///////////////
  ///Functions///
  ///////////////
  function getToken(CCIPToken token, uint64 _chainIndex) internal pure returns (address) {
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