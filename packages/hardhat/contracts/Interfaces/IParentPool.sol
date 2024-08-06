// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IPool} from "./IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        startWithdrawal_getChildPoolsLiquidity, //Start Withdrawals
        performUpkeep_requestLiquidityTransfer
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
    event ConceroPool_WithdrawRequest(
        address caller,
        address token,
        uint256 condition,
        uint256 amount
    );
    ///@notice event emitted when value is deposited into the contract
    event ConceroPool_Deposited(address indexed token, address indexed from, uint256 amount);
    ///@notice event emitted when a new withdraw request is made
    event ConceroParentPool_WithdrawRequestInitiated(
        address caller,
        IERC20 token,
        uint256 deadline
    );
    ///@notice event emitted when a value is withdraw from the contract
    event ConceroParentPool_Withdrawn(address indexed to, address token, uint256 amount);
    ///@notice event emitted when a Cross-chain tx is received.
    event ConceroParentPool_CCIPReceived(
        bytes32 indexed ccipMessageId,
        uint64 srcChainSelector,
        address sender,
        address token,
        uint256 amount
    );
    ///@notice event emitted when a Cross-chain message is sent.
    event ConceroParentPool_CCIPSent(
        bytes32 indexed messageId,
        uint64 destinationChainSelector,
        address receiver,
        address linkToken,
        uint256 fees
    );
    ///@notice event emitted in depositLiquidity when a deposit is successful executed
    event ConceroParentPool_DepositInitiated(
        bytes32 indexed requestId,
        address indexed liquidityProvider,
        uint256 _amount,
        uint256 deadline
    );
    ///@notice event emitted when a deposit is completed
    event ConceroParentPool_DepositCompleted(
        bytes32 indexed requestId,
        address indexed lpAddress,
        uint256 usdcAmount,
        uint256 _lpTokensToMint
    );
    ///@notice event emitted when a request is updated with the total USDC to withdraw
    event ConceroParentPool_RequestUpdated(bytes32 requestId);
    ///@notice event emitted when the Functions request return error
    event ConceroParentPool_CLFRequestError(
        bytes32 indexed requestId,
        RequestType requestType,
        bytes error
    );
    ///@notice event emitted when a Concero pool is added
    event ConceroParentPool_PoolReceiverUpdated(uint64 chainSelector, address pool);
    ///@notice event emitted when a allowed Cross-chain contract is updated
    event ConceroParentPool_ConceroSendersUpdated(
        uint64 chainSelector,
        address conceroContract,
        uint256 isAllowed
    );
    ///@notice event emitted in setConceroContract when the address is emitted
    event ConceroParentPool_ConceroContractUpdated(address concero);
    ///@notice event emitted when a contract is removed from the distribution array
    event ConceroParentPool_ChainAndAddressRemoved(uint64 _chainSelector);
    ///@notice event emitted when a pool is removed and the redistribution process start
    event ConceroParentPool_RedistributionStarted(bytes32 requestId);
    ///@notice event emitted when the MasterPool Cap is increased
    event ConceroParentPool_MasterPoolCapUpdated(uint256 _newCap);

    ///@notice event emitted when a new request is added
    event ConceroParentPool_RequestAdded(bytes32 requestId);
    ///@notice event emitted when the Pool Address is updated
    event ConceroParentPool_PoolAddressUpdated(address pool);
    ///@notice event emitted when the Keeper Address is updated
    event ConceroParentPool_ForwarderAddressUpdated(address forwarderAddress);
    ///@notice event emitted when a Chainlink Functions request is not fulfilled
    event FunctionsRequestError(bytes32 requestId);
    ///@notice event emitted when an upkeep is performed
    event ConceroParentPool_UpkeepPerformed(bytes32 reqId);
    ///@notice event emitted when the Don Secret is Updated
    event ConceroParentPool_DonSecretVersionUpdated(uint64 version);
    ///@notice event emitted when the Don Slot ID is updated
    event ConceroParentPool_DonHostedSlotId(uint8 slotId);
    ///@notice event emitted when the hashSum of Chainlink Function is updated
    event ConceroParentPool_HashSumUpdated(bytes32 hashSum);
    ///@notice event emitted when the Ethers HashSum is updated
    event ConceroParentPool_EthersHashSumUpdated(bytes32 hashSum);
    ///@notice event emitted when a LP retries a withdrawal request
    event ConceroParentPool_RetryPerformed(bytes32 reqId);

    /////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////FUNCTIONS//////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////
    function getWithdrawalIdByLPAddress(address lpAddress) external view returns (bytes32);
    function startDeposit(uint256 _usdcAmount) external;
    function distributeLiquidity(
        uint64 _chainSelector,
        uint256 _amountToSend,
        bytes32 distributeLiquidityRequestId
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
