//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IConceroPool {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  ///@notice ConceroPool Request
  struct WithdrawRequests {
    uint256 amountEarned;
    uint256 amountToBurn;
    uint256 amountToRequest;
    uint256 amountToReceive;
    address token;
    address liquidityProvider;
    uint256 deadline;
  }

  ///@notice `ccipSend` to distribute liquidity
  struct Pools {
    uint64 chainSelector;
    address poolAddress;
  }

  ///@notice Struct to track Functions Requests Type
  enum RequestType {
    GetTotalUSDC, //Deposits
    PerformWithdrawal //Start Withdrawals
  }

  struct CLARequest {
    RequestType requestType;
    address liquidityProvider; //address to check and pool the index from the array
    uint256 usdcBeforeDeposit;
    uint256 lpSupplyBeforeDeposit;
    uint256 depositedAmount; //USDC or LP according to the request
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
