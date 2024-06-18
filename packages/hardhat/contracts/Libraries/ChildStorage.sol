//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the caller is not the owner of the contract
error ChildStorage_NotContractOwner();
///@notice error emitted when the receiver is the address(0)
error ChildStorage_InvalidAddress();

contract ChildStorage {

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Contract Owner
  address immutable i_owner;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice variable to store the value that will be temporary used by Chainlink Functions
  uint256 public s_commits;
  ///@notice variable to store the concero contract address
  address internal s_concero;

  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) internal s_messengerAddresses;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainId => mapping(address poolAddress => uint256)) public s_poolToReceiveFrom;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Concero pool is added
  event ChildStorage_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a allowed Cross-chain contract is updated
  event ChildStorage_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256 isAllowed);
  ///@notice event emitted in setConceroContract when the address is emitted
  event ChildStorage_ConceroContractUpdated(address concero);

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier onlyOwner(){
    if(msg.sender != i_owner) revert ChildStorage_NotContractOwner();
    _;
  }

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  constructor(address _owner){
    i_owner = _owner;
  }

  ////////////////////////
  ///EXTERNAL FUNCTIONS///
  ////////////////////////
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
    if (_contractAddress == address(0)) revert ChildStorage_InvalidAddress();
    s_poolToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

    emit ChildStorage_ConceroSendersUpdated(_chainSelector, _contractAddress, _isAllowed);
  }

  /**
   * @notice function to manage the Cross-chain ConceroPool contracts
   * @param _chainSelector chain identifications
   * @param _pool address of the Cross-chain ConceroPool contract
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   * @dev this functions is used on ConceroPool.sol
   */
  function setConceroPoolReceiver(uint64 _chainSelector, address _pool) external payable onlyOwner {
    if (_pool == address(0)) revert ChildStorage_InvalidAddress();
    s_poolToSendTo[_chainSelector] = _pool;

    emit ChildStorage_PoolReceiverUpdated(_chainSelector, _pool);
  }

  function setConceroContract(address _concero) external onlyOwner{
    if (_concero == address(0)) revert ChildStorage_InvalidAddress();
    s_concero = _concero;

    emit ChildStorage_ConceroContractUpdated(_concero);
  }
}