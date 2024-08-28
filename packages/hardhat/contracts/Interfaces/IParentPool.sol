// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "./IPool.sol";

interface IParentPool is IPool {
    ///////////////////////
    ///TYPE DECLARATIONS///
    ///////////////////////

    ///@notice `ccipSend` to distribute liquidity
    struct Pools {
        uint64 chainSelector;
        address poolAddress;
    }

    ///@notice Struct to track Functions Requests Type
    enum RequestType {
        startDeposit_getChildPoolsLiquidity, //Deposits
        startWithdrawal_getChildPoolsLiquidity //Start Withdrawals
    }

    struct WithdrawRequest {
        address lpAddress;
        uint256 lpSupplySnapshot;
        uint256 lpAmountToBurn;
        //
        uint256 totalCrossChainLiquiditySnapshot; //todo: we don't update this _updateWithdrawalRequest
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
        bytes1 id;
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
    function startDeposit(uint256 _usdcAmount) external;
    function distributeLiquidity(
        uint64 _chainSelector,
        uint256 _amountToSend,
        bytes32 distributeLiquidityRequestId,
        address _ccipFeeToken
    ) external;
    function setPools(
        uint64 _chainSelector,
        address _pool,
        bool isRebalancingNeeded
    ) external payable;

    function setConceroContractSender(
        uint64 _chainSelector,
        address _contractAddress,
        uint256 _isAllowed
    ) external payable;
}
