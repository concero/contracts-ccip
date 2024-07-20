//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPool {
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
    uint256 deadline;
  }

  ///@notice `ccipSend` to distribute liquidity
  struct Pools {
    uint64 chainSelector;
    address poolAddress;
  }

  ///@notice Struct to hold ccip sent transactions
  struct CCIPPendingDeposits{
    bytes32 transactionId;
    uint64 destinationChainSelector;
    uint256 amount;
  }

  ///@notice Struct to track Functions Requests Type
  enum RequestType {
    GetTotalUSDC, //Deposits
    PerformWithdrawal //Start Withdrawals
  }

  struct CLFRequest {
    RequestType requestType;
    address liquidityProvider; //address to check and pool the index from the array
    uint256 parentPoolUsdcBeforeRequest;
    uint256 lpSupplyBeforeRequest;
    uint256 amount; //USDC or LP according to the request
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

  function getPendingWithdrawRequest(address _liquidityProvider) external view returns (WithdrawRequests memory);
}
