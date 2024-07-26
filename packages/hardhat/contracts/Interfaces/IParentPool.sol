//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPool} from "./IPool.sol";

interface IParentPool is IPool {
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
  struct CCIPPendingDeposits {
    bytes32 transactionId;
    uint64 destinationChainSelector;
    uint256 amount;
  }

  ///@notice Struct to track Functions Requests Type
  enum RequestType {
    startDeposit_getChildPoolsLiquidity, //Deposits
    startWithdrawal_getChildPoolsLiquidity //Start Withdrawals
  }

  // todo: delete
  struct CLFRequest {
    RequestType requestType;
    address liquidityProvider; //address to check and pool the index from the array
    uint256 totalCrossChainLiquiditySnapshot;
    uint256 lpSupplySnapshot;
    uint256 amount; //USDC or LP according to the request
  }

  struct WithdrawRequest {
    address lpAddress;
    uint256 totalCrossChainLiquiditySnapshot;
    uint256 lpSupplySnapshot; // may be removed?
    uint256 lpAmountToBurn; // no
  }

  struct DepositRequest {
    address lpAddress;
    uint256 totalCrossChainLiquiditySnapshot;
    uint256 usdcAmountToDeposit;
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
  function getPendingWithdrawRequest(address _liquidityProvider) external view returns (WithdrawRequests memory);
}
