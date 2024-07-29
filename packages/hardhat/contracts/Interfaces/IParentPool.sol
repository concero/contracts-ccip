// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "./IPool.sol";

interface IParentPool is IPool {
    ///////////////////////
    ///TYPE DECLARATIONS///
    ///////////////////////
    ///@notice ConceroPool Request
    //    struct WithdrawRequests {
    //        uint256 amountToWithdraw;
    //        uint256 lpAmountToBurn;
    //        uint256 liquidityRequestedFromEachPool;
    //        uint256 remainingLiquidityFromChildPools;
    //        address token;
    //        uint256 deadline;
    //    }

    ///@notice `ccipSend` to distribute liquidity
    struct Pools {
        uint64 chainSelector;
        address poolAddress;
    }

    ///@notice Struct to hold ccip sent transactions
    // deleted
    //    struct CCIPPendingDeposits {
    //        bytes32 transactionId;
    //        uint64 destinationChainSelector;
    //        uint256 amount;
    //    }

    ///@notice Struct to track Functions Requests Type
    enum RequestType {
        startDeposit_getChildPoolsLiquidity, //Deposits
        startWithdrawal_getChildPoolsLiquidity //Start Withdrawals
    }

    // todo: delete
    //    struct CLFRequest {
    //        RequestType requestType;
    //        address liquidityProvider; //address to check and pool the index from the array
    //        uint256 totalCrossChainLiquiditySnapshot;
    //        uint256 lpSupplySnapshot;
    //        uint256 amount; //USDC or LP according to the request
    //    }

    struct WithdrawRequest {
        address lpAddress;
        uint256 lpSupplySnapshot;
        uint256 lpAmountToBurn;
        //
        uint256 totalCrossChainLiquiditySnapshot;
        uint256 amountToWithdraw;
        uint256 liquidityRequestedFromEachPool; // this may be calculated by CLF later
        uint256 remainingLiquidityFromChildPools;
        uint256 triggeredAtTimestamp;
    }

    struct DepositRequest {
        address lpAddress;
        uint256 childPoolsLiquiditySnapshot;
        uint256 usdcAmountToDeposit;
        uint256 deadline;
    }

    struct DepositOnTheWay {
        uint8 id;
        uint64 chainSelector;
        bytes32 ccipMessageId;
        uint256 amount;
    }

    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////
    ///@notice event emitted when a new withdraw request is made
    event ConceroPool_WithdrawRequest(
        address caller,
        address token,
        uint256 condition,
        uint256 amount
    );
    ///@notice event emitted when value is deposited into the contract
    event ConceroPool_Deposited(address indexed token, address indexed from, uint256 amount);

    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////FUNCTIONS//////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////
    function getWithdrawalRequestById(
        bytes32 _withdrawalId
    ) external view returns (WithdrawRequest memory);

    function getWithdrawalIdByLPAddress(address lpAddress) external view returns (bytes32);
    function addWithdrawalOnTheWayAmountById(bytes32 _withdrawalId) external;
}
