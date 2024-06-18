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
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  ///@notice `ccipSend` to distribute liquidity
  struct Pools {
    uint64 chainSelector;
    address poolAddress;
  }

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///@notice variable to store the max value that can be deposited on this pool
  uint256 internal s_maxDeposit;
  ///@notice variable to store the total value deposited
  uint256 internal s_usdcPoolReserve;
  ///@notice variable to store the value that will be temporary used by Chainlink Functions
  uint256 internal s_commit;
  ///@notice variable to store the concero contract address
  address internal s_concero;

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Contract Owner
  address immutable i_owner;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  Pools[] poolsToDistribute;

  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) public s_messengerAddresses;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainSelector => mapping(address poolAddress => uint256)) public s_contractsToReceiveFrom;
  ///@notice Mapping to keep track of Liquidity Providers withdraw requests
  mapping(address _liquidityProvider => IConceroPool.WithdrawRequests) public s_pendingWithdrawRequests;

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
  event MasterStorage_ChainAndAddressRemoved(uint64 _chainSelector, address poolAddress);

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
    s_contractsToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

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
    poolsToDistribute.push(Pools({chainSelector: _chainSelector, poolAddress: _pool}));

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
    emit MasterStorage_ChainAndAddressRemoved(_chainSelector, s_poolToSendTo[_chainSelector]);
  }

  /**
   * @notice function to add Concero Contract address to storage
   * @param _concero the address of Concero Contract
   * @dev The address will be use to control access on `orchestratorLoan`
   */
  function setConceroContract(address _concero) external payable onlyOwner {
    if (_concero == address(0)) revert MasterStorage_InvalidAddress();

    s_concero = _concero;

    emit MasterStorage_ConceroContractUpdated(_concero);
  }
}
