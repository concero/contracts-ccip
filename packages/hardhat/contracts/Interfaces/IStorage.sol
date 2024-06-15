//SPDX-License-Identificer: MIT
pragma solidity 0.8.20;

interface IStorage {
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
  }
  ///@notice `ccipSend` to distribute liquidity
  struct Pools {
    uint64 chainSelector;
    address poolAddress;
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
  ///@notice Chainlink Functions Variables
  struct FunctionsVariables {
    uint8 donHostedSecretsSlotId;
    uint64 donHostedSecretsVersion;
    uint64 subscriptionId;
    bytes32 donId;
    address functionsRouter;
  }
}
