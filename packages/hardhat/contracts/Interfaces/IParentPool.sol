// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "./IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IInfraStorage} from "./IInfraStorage.sol";
import {ICCIP} from "./ICCIP.sol";

interface IParentPool is IPool {
    ///////////////////////
    ///TYPE DECLARATIONS///
    ///////////////////////

    enum FunctionsRequestType {
        getTotalPoolsBalance,
        liquidityRedistribution,
        withdrawalLiquidityCollection
    }

    enum RedistributeLiquidityType {
        addPool,
        removePool
    }

    ///@notice `ccipSend` to distribute liquidity
    struct Pools {
        uint64 chainSelector;
        address poolAddress;
    }

    ///@notice Struct to track Functions Requests Type
    enum CLFRequestType {
        startDeposit_getChildPoolsLiquidity, //Deposits
        startWithdrawal_getChildPoolsLiquidity, //Start Withdrawals
        performUpkeep_requestLiquidityTransfer
    }

    struct WithdrawRequest {
        address lpAddress;
        uint256 lpSupplySnapshot_DEPRECATED;
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
        uint64 chainSelector;
        bytes32 ccipMessageId;
        uint256 amount;
    }

    struct DepositOnTheWay_DEPRECATED {
        bytes1 id;
        uint64 chainSelector;
        bytes32 ccipMessageId;
        uint256 amount;
    }

    struct PerformWithdrawRequest {
        address liquidityProvider;
        uint256 amount;
        bytes32 withdrawId;
        bool failed;
    }

    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////

    ///@notice event emitted when a new withdraw request is made
    event WithdrawalRequestInitiated(
        bytes32 indexed requestId,
        address caller,
        IERC20 token,
        uint256 deadline
    );
    ///@notice event emitted when a value is withdraw from the contract
    event WithdrawalCompleted(
        bytes32 indexed requestId,
        address indexed to,
        address token,
        uint256 amount
    );
    ///@notice event emitted when a Cross-chain tx is received.
    event CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );
    ///@notice event emitted when a Cross-chain message is sent.
    event CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    );
    ///@notice event emitted in depositLiquidity when a deposit is successful executed
    event DepositInitiated(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        uint256 _amount,
        uint256 deadline
    );
    ///@notice event emitted when a deposit is completed
    event DepositCompleted(
        bytes32 indexed requestId,
        address indexed lpAddress,
        uint256 usdcAmount,
        uint256 _lpTokensToMint
    );

    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////FUNCTIONS//////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////
    function getWithdrawalIdByLPAddress(address lpAddress) external view returns (bytes32);
    function startDeposit(uint256 _usdcAmount) external;
    function distributeLiquidity(
        uint64 _chainSelector,
        uint256 _amountToSend,
        bytes32 distributeLiquidityRequestId,
        ICCIP.CcipTxType _ccipTxType
    ) external;
    function setPools(
        uint64 _chainSelector,
        address _pool,
        bool isRebalancingNeeded
    ) external payable;

    function setConceroContractSender(
        uint64 _chainSelector,
        address _contractAddress,
        bool _isAllowed
    ) external payable;

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function setPoolCap(uint256 _newCap) external payable;
}
