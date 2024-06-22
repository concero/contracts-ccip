//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IConceroPool} from "contracts/Interfaces/IConceroPool.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when an Admin enters an address(0) as input
error MasterStorage_InvalidAddress();
///@notice error emitted when the caller is not the owner
error MasterStorage_NotContractOwner();
///@notice error emitted when the owner tries to add an receiver that was already added.
error MasterStorage_DuplicatedAddress();

contract MasterStorage {
  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///@notice variable to store the max value that can be deposited on this pool
  uint256 internal s_maxDeposit;
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 internal s_donHostedSecretsSlotId;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 internal s_hashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 internal s_ethersHashSum;
  ///@notice variable to store the value that will be temporary used by Chainlink Functions
  uint256 public s_loansInUse;

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Contract Owner
  address immutable i_owner;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  IConceroPool.Pools[] poolsToDistribute;

  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainSelector => mapping(address poolAddress => uint256)) public s_poolToReceiveFrom;
  ///@notice Mapping to keep track of Liquidity Providers withdraw requests
  mapping(address _liquidityProvider => IConceroPool.WithdrawRequests) public s_pendingWithdrawRequests;
  ///@notice Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 requestId => IConceroPool.CLARequest) public s_requests;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event MasterStorage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a allowed Cross-chain contract is updated
  event MasterStorage_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256 isAllowed);
  ///@notice event emitted in setConceroContract when the address is emitted
  event MasterStorage_ConceroContractUpdated(address concero);
  ///@notice event emitted when a contract is removed from the distribution array
  event MasterStorage_ChainAndAddressRemoved(uint64 _chainSelector);
  ///@notice event emitted when the MasterPool Cap is increased
  event MasterStorage_MasterPoolCapUpdated(uint256 _newCap);

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier onlyOwner() {
    if (msg.sender != i_owner) revert MasterStorage_NotContractOwner();
    _;
  }

  constructor(address _owner) {
    i_owner = _owner;
  }

  ///////////////////////
  ///SETTERS FUNCTIONS///
  ///////////////////////
  /**
   * @notice function to manage the Cross-chains Concero contracts
   * @param _chainSelector chain identifications
   * @param _contractAddress address of the Cross-chains Concero contracts
   * @param _isAllowed 1 == allowed | Any other value == not allowed
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   * @dev this functions is used on ConceroPool.sol
   */
  function setConceroContractSender(uint64 _chainSelector, address _contractAddress, uint256 _isAllowed) external payable onlyOwner {
    if (_contractAddress == address(0)) revert MasterStorage_InvalidAddress();
    s_poolToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

    emit MasterStorage_ConceroSendersUpdated(_chainSelector, _contractAddress, _isAllowed);
  }

  /**
   * @notice function to manage the Cross-chain ConceroPool contracts
   * @param _chainSelector chain identifications
   * @param _pool address of the Cross-chain ConceroPool contract
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   * @dev this functions is used on ConceroPool.sol
   */
  function setPoolsToSend(uint64 _chainSelector, address _pool) external payable onlyOwner {
    if (s_poolToSendTo[_chainSelector] != address(0)) revert MasterStorage_DuplicatedAddress();
    poolsToDistribute.push(IConceroPool.Pools({chainSelector: _chainSelector, poolAddress: _pool}));

    s_poolToSendTo[_chainSelector] = _pool;

    emit MasterStorage_PoolReceiverUpdated(_chainSelector, _pool);
  }

  /**
   * @notice Function to remove Cross-chain address disapproving transfers
   * @param _chainSelector the CCIP chainSelector for the specific chain
   */
  function removePoolsFromListOfSenders(uint64 _chainSelector) external payable onlyOwner {
    uint256 arrayLength = poolsToDistribute.length;
    for (uint256 i; i < arrayLength; ) {
      if (poolsToDistribute[i].chainSelector == _chainSelector) {
        poolsToDistribute[i] = poolsToDistribute[poolsToDistribute.length - 1];
        poolsToDistribute.pop();
        delete s_poolToSendTo[_chainSelector];
      }
      unchecked {
        ++i;
      }
    }
    emit MasterStorage_ChainAndAddressRemoved(_chainSelector);
  }

  /**
   * @notice Function to set the Cap of the Master pool.
   * @param _newCap The new Cap of the pool
   */
  function setPoolCap(uint256 _newCap) external payable onlyOwner {
    s_maxDeposit = _newCap;

    emit MasterStorage_MasterPoolCapUpdated(_newCap);
  }
}
