// SPDX-License-Identifier: UNLICENSED
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
    ///@notice variable to store the Chainlink Function DON Slot ID
    uint8 internal s_donHostedSecretsSlotId;
    ///@notice variable to store the Chainlink Function DON Secret Version
    uint64 internal s_donHostedSecretsVersion;
    ///@notice variable to store the Chainlink Function Source Hashsum
    bytes32 internal s_hashSum;
    ///@notice variable to store Ethers Hashsum
    bytes32 internal s_ethersHashSum;
    ///@notice variable to store not processed amounts deposited by LPs
    uint256 public s_depositsOnTheWayAmount;

    uint8 internal s_latestDepositOnTheWayId;

    uint256 internal s_depositFeeAmount;

    ///@notice variable to store the amount requested in withdraws, incremented at startWithdrawal, decremented at completewithdrawal
    uint256 public s_withdrawAmountLocked;
    //incremented when ccipSend is called on child pools by CLA, decremented with each ccipReceive
    uint256 internal s_withdrawalsOnTheWayAmount;
    ///@notice gap to reserve storage in the contract for future variable additions
    uint256[50] private __gap;

    /////////////
    ///STORAGE///
    /////////////
    ///@notice array of Pools to receive Liquidity through `ccipSend` function
    uint64[] internal s_poolChainSelectors;
    IParentPool.DepositOnTheWay[] internal s_depositsOnTheWayArray;

    ///@notice Mapping to keep track of valid pools to transfer in case of liquidation or rebalance
    mapping(uint64 chainSelector => address pool) public s_poolToSendTo;
    //todo: rename s_poolToSendTo to childPools

    ///@notice Mapping to keep track of allowed pool senders
    mapping(uint64 chainSelector => mapping(address poolAddress => uint256)) public s_contractsToReceiveFrom;

    ///@notice Mapping to keep track of Liquidity Providers withdraw requests
    mapping(bytes32 => bool) public s_distributeLiquidityRequestProcessed;

    mapping(bytes32 clfReqId => IParentPool.RequestType) public s_clfRequestTypes;

    mapping(bytes32 clfReqId => IParentPool.DepositRequest) public s_depositRequests;

    mapping(address lpAddress => bytes32 withdrawalId) public s_withdrawalIdByLPAddress;

    mapping(bytes32 clfReqId => bytes32 withdrawalId) public s_withdrawalIdByCLFRequestId;

    mapping(bytes32 withdrawalId => IParentPool.WithdrawRequest) public s_withdrawRequests;

    ///@notice variable to store the automation keeper address
    address public s_forwarderAddress;

    ///@notice array to store the withdraw requests of users
    bytes32[] public s_withdrawalRequestIds;

    ///@notice Mapping to keep track of Chainlink Functions requests
    mapping(bytes32 withdrawalId => bool isTriggered) public s_withdrawTriggered;
}
