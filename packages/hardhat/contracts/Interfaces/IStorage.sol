// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IStorage {
    ///@notice Chainlink Functions Request Type
    enum RequestType {
        addUnconfirmedTxDst,
        checkTxSrc
    }

    ///@notice CCIP Compatible Tokens
    //REMOVE IN PRODUCTION : bnm
    enum CCIPToken {
        bnm,
        usdc
    }

    ///@notice Operational Chains
    enum Chain {
        arb,
        base,
        opt,
        pol,
        avax,
        eth
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
        uint64 dstChainSelector;
        address receiver;
    }

    ///@notice `ccipSend` to distribute liquidity
    struct Pools {
        uint64 chainSelector;
        address poolAddress;
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
        bytes dstSwapData;
    }

    ///@notice Chainlink Functions Variables
    struct FunctionsVariables {
        uint64 subscriptionId;
        bytes32 donId;
        address functionsRouter;
    }
}
