//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

contract ParentPoolStorage {
    /////////////////////
    ///STATE VARIABLES///
    /////////////////////

    ///@notice variable to store the max value that can be deposited on this pool
    uint256 public s_maxDeposit;
    ///@notice variable to store the amount that will be temporary used by Chainlink Functions
    uint256 public s_loansInUse;
    ///@notice variable to store the amount requested in withdraws
    uint256 public s_currentWithdrawRequestsAmount;
    ///@notice variable to store the Chainlink Function DON Slot ID
    uint8 internal s_donHostedSecretsSlotId;
    ///@notice variable to store the Chainlink Function DON Secret Version
    uint64 internal s_donHostedSecretsVersion;
    ///@notice variable to store the Chainlink Function Source Hashsum
    bytes32 internal s_hashSum;
    ///@notice variable to store Ethers Hashsum
    bytes32 internal s_ethersHashSum;
    ///@notice variable to store not processed amounts deposited by LPs
    // TODO: mb remove this variable
    uint256 public s_depositsOnTheWay;
    ///@notice gap to reserve storage in the contract for future variable additions
    uint256[49] __gap;

    /////////////
    ///STORAGE///
    /////////////
    ///@notice array of Pools to receive Liquidity through `ccipSend` function
    uint64[] s_poolChainSelectors;

    ///@notice Mapping to keep track of valid pools to transfer in case of liquidation or rebalance
    mapping(uint64 chainSelector => address pool) public s_poolToSendTo;
    ///@notice Mapping to keep track of allowed pool senders
    mapping(uint64 chainSelector => mapping(address poolAddress => uint256))
        public s_contractsToReceiveFrom;
    ///@notice Mapping to keep track of Liquidity Providers withdraw requests
    // DELETED
    //    mapping(address _liquidityProvider => IParentPool.WithdrawRequest)
    //        public s_pendingWithdrawRequests;
    ///@notice Mapping to keep track of Chainlink Functions requests
    // todo : delete
    //    mapping(bytes32 requestId => IParentPool.CLFRequest) public s_requests;

    ////////////////////////
    ////NEW STORAGE VARS////
    ////////////////////////

    mapping(bytes32 => bool) public s_distributeLiquidityRequestProcessed;
    mapping(bytes32 messageId => IParentPool.CCIPPendingDeposits) internal s_ccipDepositsMapping;
    IParentPool.CCIPPendingDeposits[] s_ccipDeposits;

    mapping(address lpAddress => bytes32 withdrawalId) public s_withdrawalIdByLPAddress;
    mapping(bytes32 clfReqId => bytes32 withdrawalId) public s_withdrawalIdByCLFRequestId;
    mapping(bytes32 clfReqId => IParentPool.RequestType) public s_clfRequestTypes;
    mapping(bytes32 clfReqId => IParentPool.WithdrawRequest) public s_withdrawRequests;
    mapping(bytes32 clfReqId => IParentPool.DepositRequest) public s_depositRequests;

    IParentPool.DepositOnTheWay[] internal s_depositsOnTheWayArray;
    uint8 internal s_latestDepositOnTheWayId;
}
