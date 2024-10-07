// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IInfraStorage} from "../Interfaces/IInfraStorage.sol";

abstract contract InfraStorage is ReentrancyGuard, IInfraStorage {
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
    mapping(uint64 chainSelector => uint256 lastGasPrice) public s_lastGasPrices;

    ///@notice Bridge: mapping to track pending batched CCIP tx amount per destination chain
    mapping(uint64 dstChainSelector => uint256 amount) public s_pendingSettlementTxAmountByDstChain;
    ///@notice Bridge: mapping to track pending CCIP txs for batched execution per destination chain
    mapping(uint64 dstChainSelector => bytes32[] bridgeTxIds)
        public s_pendingSettlementTxsByDstChain;
    ///@notice Bridge: mapping to track transaction details
    mapping(bytes32 bridgeTxId => SettlementTx pendingTx) public s_pendingSettlementTxsById;

    ///@notice Bridge: mapping to track last CCIP tx fee in LINK for each destination chain
    mapping(uint64 dstChainSelector => uint256 lastCCIPFeeInLink) internal s_lastCCIPFeeInLink;

    ///@notice Orchestrator/Bridge: Tracks the fees earned in each token for integrators
    mapping(address integrator => mapping(address token => uint256 feesEarned))
        internal s_integratorFeesEarned;
    ///@notice Orchestrator/Bridge: Tracks the total fees earned per token
    mapping(address token => uint256 totalFeesEarned) internal s_totalIntegratorFeesEarnedPerToken;
}
