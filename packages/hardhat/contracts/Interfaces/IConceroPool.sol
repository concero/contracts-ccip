//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IConceroPool {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  ///@notice ConceroPool Request
  struct WithdrawRequests {
    uint256 amount;
    uint256 amountToBurn;
    uint256 receivedAmount;
    address token;
    address sender;
    uint256 deadline;
  }
  
  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a new withdraw request is made
  event ConceroPool_WithdrawRequest(address caller, address token, uint256 condition, uint256 amount);
  ///@notice event emitted when value is deposited into the contract
  event ConceroPool_Deposited(address indexed token, address indexed from, uint256 amount);

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  function orchestratorLoan(address _token, uint256 _amount, address _receiver) external;

  function withdrawLiquidityRequest(address _token, uint256 _amount) external;

  function depositEther() external payable;

  function depositToken(address _token, uint256 _amount) external;
}