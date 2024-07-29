// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

contract ChildPoolStorage {
    /////////////////////
    ///STATE VARIABLES///
    /////////////////////
    ///@notice variable to store the value that will be temporary used by Chainlink Functions
    uint256 public s_loansInUse;
    ///@notice gap to reserve storage in the contract for future variable additions
    uint256[50] __gap;

    /////////////
    ///STORAGE///
    /////////////
    ///@notice array of chain IDS of Pools to receive Liquidity through `ccipSend` function
    uint64[] s_poolChainSelectors;

    ///@notice Mapping to keep track of allowed pool senders
    mapping(uint64 chainSelector => mapping(address conceroContract => uint256))
        public s_contractsToReceiveFrom;
    ///@notice Mapping to keep track of valid pools to transfer in case of liquidation or rebalance
    mapping(uint64 chainSelector => address pools) public s_poolToSendTo;

    ////////////////////////
    ////NEW STORAGE VARS////
    ////////////////////////

    mapping(bytes32 => bool) public s_distributeLiquidityRequestProcessed;
    mapping(bytes32 => bool) public s_withdrawRequests;
}
