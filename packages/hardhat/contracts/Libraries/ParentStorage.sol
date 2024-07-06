//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////

///@notice error emitted when the caller is not the owner
error ParentStorage_NotContractOwner();

contract ParentStorage {
  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Contract Owner
  address immutable i_owner;

  ///////////
  ///STATE///
  ///////////

  ///@notice variable to store the max value that can be deposited on this pool
  uint256 public s_maxDeposit;
  ///@notice variable to store the amount that will be temporary used by Chainlink Functions
  uint256 public s_loansInUse;
  ///@notice variable to store the amount requested in withdraws
  uint256 public s_withdrawRequests;
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 internal s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 internal s_hashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 internal s_ethersHashSum;
  ///@notice gap to reserve storage in the contract for future variable additions
  uint256[50] __gap;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  IParentPool.Pools[] s_poolsToDistribute;

  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainSelector => mapping(address poolAddress => uint256)) public s_contractsToReceiveFrom;
  ///@notice Mapping to keep track of Liquidity Providers withdraw requests
  mapping(address _liquidityProvider => IParentPool.WithdrawRequests) public s_pendingWithdrawRequests;
  ///@notice Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 requestId => IParentPool.CLFRequest) public s_requests;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event ParentStorage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a allowed Cross-chain contract is updated
  event ParentStorage_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256 isAllowed);
  ///@notice event emitted in setConceroContract when the address is emitted
  event ParentStorage_ConceroContractUpdated(address concero);
  ///@notice event emitted when a contract is removed from the distribution array
  event ParentStorage_ChainAndAddressRemoved(uint64 _chainSelector);
  ///@notice event emitted when the MasterPool Cap is increased
  event ParentStorage_MasterPoolCapUpdated(uint256 _newCap);

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier onlyOwner() {
    if (msg.sender != i_owner) revert ParentStorage_NotContractOwner();
    _;
  }

  constructor(address _owner) {
    i_owner = _owner;
  }
}
