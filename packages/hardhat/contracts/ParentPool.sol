// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {LPToken} from "./LPToken.sol";
import {IParentPool} from "./Interfaces/IParentPool.sol";
import {IStorage} from "./Interfaces/IStorage.sol";
import {ParentPoolStorage} from "contracts/Libraries/ParentPoolStorage.sol";
import {IOrchestrator} from "./Interfaces/IOrchestrator.sol";
import {ParentPoolCommon} from "./ParentPoolCommon.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the receiver is the address(0)
error ConceroParentPool_InvalidAddress();
///@notice error emitted when the caller is not a valid Messenger
error ConceroParentPool_NotMessenger(address caller);
///@notice error emitted when the CCIP message sender is not allowed.
error ConceroParentPool_SenderNotAllowed(address _sender);
///@notice error emitted when an attempt to create a new request is made while other is still active.
error ConceroParentPool_ActiveRequestNotFulfilledYet();
///@notice emitted in depositLiquidity when the input amount is not enough
error ConceroParentPool_AmountBelowMinimum(uint256 minAmount);
///@notice emitted in withdrawLiquidity when the amount to withdraws is bigger than the balance
error ConceroParentPool_WithdrawalAmountNotReady(uint256 received);
///@notice error emitted when the caller is not the Orchestrator
error ConceroParentPool_NotInfraProxy(address caller);
///@notice error emitted when the max amount accepted by the pool is reached
error ConceroParentPool_MaxCapReached(uint256 maxCap);
///@notice error emitted when it's not the proxy calling the function
error ConceroParentPool_NotParentPoolProxy(address caller);
///@notice error emitted when the input TX was already removed
error ConceroParentPool_NotContractOwner();
error ConceroParentPool_RequestAlreadyProceeded(bytes32 requestId);
///@notice error emitted when the caller is not the LP who opened the request
error ConceroParentPool_NotAllowedToComplete();
///@notice error emitted when the request doesn't exist
error ConceroParentPool_RequestDoesntExist();

///@notice error emitted when the caller is not the owner.
error ConceroParentPool_CallerNotAllowed(address caller);
error ConceroParentPool_WithdrawAlreadyTriggered(bytes32 withdrawalId);
error ConceroParentPool_WithdrawRequestDoesntExist(bytes32 withdrawalId);
error ConceroParentPool_WithdrawRequestNotReady(bytes32 withdrawalId);
error ConceroParentPool_DepositsOnTheWayArrayFull();

contract ParentPool is IParentPool, CCIPReceiver, ParentPoolCommon, ParentPoolStorage {
    ///////////////////////
    ///TYPE DECLARATIONS///
    ///////////////////////
    using FunctionsRequest for FunctionsRequest.Request;
    using SafeERC20 for IERC20;

    ///////////////
    ///CONSTANTS///
    ///////////////

    uint256 internal constant MIN_DEPOSIT = 100_000_000;
    uint256 internal constant DEPOSIT_DEADLINE_SECONDS = 60;
    uint256 private constant CLA_PERFORMUPKEEP_ITERATION_GAS_COSTS = 2108;
    uint256 private constant ARRAY_MANIPULATION = 10_000;
    uint256 private constant AUTOMATION_OVERHEARD = 80_000;
    uint256 private constant NODE_PREMIUM = 150;
    ///@notice variable to access parent pool costs
    uint64 private constant BASE_CHAIN_SELECTOR = 15971525489660198786;
    ///@notice variable to store the costs of updating store on CLF callback
    uint256 private constant WRITE_FUNCTIONS_COST = 600_000;
    ///@notice Chainlink Functions Gas Limit
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * 10 ** 6;

    ////////////////
    ///IMMUTABLES///
    ////////////////

    ///@notice Orchestrator Proxy immutable address
    address private immutable i_infraProxy;
    ///@notice Chainlink Link Token interface
    LinkTokenInterface private immutable i_linkToken;
    ///@notice Chainlink Functions Protocol Subscription ID
    address internal immutable i_parentPoolCLACLF;
    address internal immutable i_owner;
    IERC20 internal immutable i_USDC;

    ///////////////
    ///MODIFIERS///
    ///////////////
    /**
     * @notice CCIP Modifier to check Chains And senders
     * @param _chainSelector Id of the source chain of the message
     * @param _sender address of the sender contract
     */
    modifier onlyAllowlistedSenderOfChainSelector(uint64 _chainSelector, address _sender) {
        if (s_contractsToReceiveFrom[_chainSelector][_sender] != ALLOWED) {
            revert ConceroParentPool_SenderNotAllowed(_sender);
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NotContractOwner(msg.sender);
        _;
    }

    constructor(
        address _parentPoolProxy,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _lpToken,
        address _infraProxy,
        address _owner,
        address[3] memory _messengers
    ) CCIPReceiver(_ccipRouter) ParentPoolCommon() {
        i_linkToken = LinkTokenInterface(_link);
        i_USDC = IERC20(_usdc);
        i_infraProxy = _infraProxy;
    }

    ////////////////////////
    ///EXTERNAL FUNCTIONS///
    ////////////////////////
    /**
     * @notice function for the Concero Orchestrator contract to take loans
     * @param _token address of the token being loaned
     * @param _amount being loaned
     * @param _receiver address of the user that will receive the amount
     * @dev only the Orchestrator contract should be able to call this function
     * @dev for ether transfer, the _receiver need to be known and trusted
     */
    function takeLoan(
        address _token,
        uint256 _amount,
        address _receiver
    ) external payable onlyProxyContext {
        if (msg.sender != i_infraProxy) revert ConceroParentPool_NotInfraProxy(msg.sender);
        if (_receiver == address(0)) revert ConceroParentPool_InvalidAddress();

        IERC20(_token).safeTransfer(_receiver, _amount);
        s_loansInUse += _amount;
    }

    /**
     * @notice Function for user to deposit liquidity of allowed tokens
     * @param _usdcAmount the amount to be deposited
     */
    function startDeposit(uint256 _usdcAmount) external onlyProxyContext {
        if (_usdcAmount < MIN_DEPOSIT) revert ConceroParentPool_AmountBelowMinimum(MIN_DEPOSIT);

        uint256 maxDeposit = s_maxDeposit;

        if (
            maxDeposit != 0 &&
            _usdcAmount +
                i_USDC.balanceOf(address(this)) -
                s_depositFeeAmount +
                s_loansInUse -
                s_withdrawAmountLocked >
            maxDeposit
        ) {
            revert ConceroParentPool_MaxCapReached(maxDeposit);
        }

        // uint256 depositFee = _calculateDepositTransactionFee(_usdcAmount);
        // uint256 depositMinusFee = _usdcAmount - _convertToUSDCTokenDecimals(depositFee);

        bytes[] memory args = new bytes[](3);
        args[0] = abi.encodePacked(s_getBalanceJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(FunctionsRequestType.getTotalPoolsBalance);

        bytes32 clfRequestId = _sendRequest(args, JS_CODE);
        s_clfRequestTypes[clfRequestId] = RequestType.startDeposit_getChildPoolsLiquidity;

        uint256 _deadline = block.timestamp + DEPOSIT_DEADLINE_SECONDS;

        s_depositRequests[clfRequestId].lpAddress = msg.sender;
        s_depositRequests[clfRequestId].usdcAmountToDeposit = _usdcAmount;
        s_depositRequests[clfRequestId].deadline = _deadline;

        emit ConceroParentPool_DepositInitiated(clfRequestId, msg.sender, _usdcAmount, _deadline);
    }

    function completeDeposit(bytes32 _depositRequestId) external onlyProxyContext {
        DepositRequest storage request = s_depositRequests[_depositRequestId];
        address lpAddress = request.lpAddress;
        uint256 usdcAmount = request.usdcAmountToDeposit;
        uint256 usdcAmountAfterFee = usdcAmount - DEPOSIT_FEE_USDC;
        uint256 childPoolsLiquiditySnapshot = request.childPoolsLiquiditySnapshot;

        if (msg.sender != lpAddress) revert ConceroParentPool_NotAllowedToComplete();
        if (childPoolsLiquiditySnapshot == 0) {
            revert ConceroParentPool_ActiveRequestNotFulfilledYet();
        }

        uint256 lpTokensToMint = _calculateLPTokensToMint(
            childPoolsLiquiditySnapshot,
            usdcAmountAfterFee
        );

        i_USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        i_lpToken.mint(msg.sender, lpTokensToMint);

        _distributeLiquidityToChildPools(usdcAmountAfterFee);

        s_depositFeeAmount += DEPOSIT_FEE_USDC;

        emit ConceroParentPool_DepositCompleted(
            _depositRequestId,
            msg.sender,
            usdcAmount,
            lpTokensToMint
        );

        delete s_depositRequests[_depositRequestId];
        delete s_clfRequestTypes[_depositRequestId];
    }

    /**
     * @notice Function to allow Liquidity Providers to start the Withdraw of their USDC deposited
     * @param _lpAmount the amount of lp token the user wants to burn to get USDC back.
     */
    function startWithdrawal(uint256 _lpAmount) external onlyProxyContext {
        if (_lpAmount == 0) revert ConceroParentPool_AmountBelowMinimum(1);
        if (s_withdrawalIdByLPAddress[msg.sender] != bytes32(0)) {
            revert ConceroParentPool_ActiveRequestNotFulfilledYet();
        }

        bytes[] memory args = new bytes[](2);
        args[0] = abi.encodePacked(s_getBalanceJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);

        bytes32 withdrawalId = keccak256(
            abi.encodePacked(msg.sender, _lpAmount, block.number, block.prevrandao)
        );

        IERC20(i_lpToken).safeTransferFrom(msg.sender, address(this), _lpAmount);

        bytes32 clfRequestId = _sendRequest(args, JS_CODE);
        s_clfRequestTypes[clfRequestId] = RequestType.startWithdrawal_getChildPoolsLiquidity;

        // partially initialise withdrawalRequest struct
        s_withdrawRequests[withdrawalId].lpAddress = msg.sender;
        s_withdrawRequests[withdrawalId].lpSupplySnapshot = i_lpToken.totalSupply();
        s_withdrawRequests[withdrawalId].lpAmountToBurn = _lpAmount;

        s_withdrawalIdByCLFRequestId[clfRequestId] = withdrawalId;
        s_withdrawalIdByLPAddress[msg.sender] = withdrawalId;

        emit ConceroParentPool_WithdrawRequestInitiated(
            withdrawalId,
            msg.sender,
            i_USDC,
            block.timestamp + WITHDRAW_DEADLINE_SECONDS
        );
    }

    /**
     * @notice Function called to finalize the withdraw process.
     * @dev The msg.sender will be used to load the withdraw request data
     * if the request received the total amount requested from other pools,
     * the withdraw will be finalize. If not, it must revert
     */
    function completeWithdrawal() external onlyProxyContext {
        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];
        if (withdrawalId == bytes32(0)) revert ConceroParentPool_RequestDoesntExist();

        WithdrawRequest memory withdrawRequest = s_withdrawRequests[withdrawalId];

        uint256 amountToWithdraw = withdrawRequest.amountToWithdraw;
        uint256 lpAmountToBurn = withdrawRequest.lpAmountToBurn;
        uint256 remainingLiquidityFromChildPools = withdrawRequest.remainingLiquidityFromChildPools;

        if (amountToWithdraw == 0) revert ConceroParentPool_ActiveRequestNotFulfilledYet();

        if (remainingLiquidityFromChildPools > 10) {
            revert ConceroParentPool_WithdrawalAmountNotReady(remainingLiquidityFromChildPools);
        }

        s_withdrawAmountLocked = s_withdrawAmountLocked > amountToWithdraw
            ? s_withdrawAmountLocked - amountToWithdraw
            : 0;

        // uint256 withdrawFees = _calculateWithdrawTransactionsFee(withdraw.amountToWithdraw);
        // uint256 withdrawAmountMinusFees = withdraw.amountToWithdraw - _convertToUSDCTokenDecimals(withdrawFees);

        delete s_withdrawalIdByLPAddress[msg.sender];
        delete s_withdrawRequests[withdrawalId];

        i_lpToken.burn(lpAmountToBurn);

        i_USDC.safeTransfer(msg.sender, amountToWithdraw);

        emit ConceroParentPool_Withdrawn(
            withdrawalId,
            msg.sender,
            address(i_USDC),
            amountToWithdraw
        );
    }

    /**
     * @notice Function called by Messenger to send USDC to a recently added pool.
     * @param _chainSelector The chain selector of the new pool
     * @param _amountToSend the amount to redistribute between pools.
     */
    function distributeLiquidity(
        uint64 _chainSelector,
        uint256 _amountToSend,
        bytes32 distributeLiquidityRequestId
    ) external onlyProxyContext onlyMessenger {
        if (s_childPools[_chainSelector] == address(0)) revert ConceroParentPool_InvalidAddress();
        if (s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] != false) {
            revert ConceroParentPool_RequestAlreadyProceeded(distributeLiquidityRequestId);
        }
        s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] = true;
        _ccipSend(_chainSelector, _amountToSend);
    }

    receive() external payable {}

    function withdrawDepositFees() external payable onlyOwner {
        i_USDC.safeTransfer(i_owner, s_depositFeeAmount);
        s_depositFeeAmount = 0;
    }

    ////////////////////////
    /////VIEW FUNCTIONS/////
    ////////////////////////

    function delegateCallWrapper(bytes memory data, address target) internal returns (uint256) {
        (bool success, bytes memory data) = target.delegatecall(data);

        if (!success) {
            revert UnableToCompleteDelegateCall(data);
        }
        return data;
    }

    function calculateLpAmount(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256) {
        bytes memory data = abi.encodeWithSelector(
            IParentPoolCCIP.calculateLpAmount.selector,
            childPoolsBalance,
            amountToDeposit
        );

        return
            IParentPoolViewViaDelegate(address(this)).calculateLpAmountViaDelegate(
                data,
                i_parentPoolCCIP
            );
    }

    /**
     * @notice Internal function to convert USDC Decimals to LP Decimals
     * @param _usdcAmount the amount of USDC
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToLPTokenDecimals(uint256 _usdcAmount) internal pure returns (uint256) {
        return (_usdcAmount * LP_TOKEN_DECIMALS) / USDC_DECIMALS;
    }

    /**
     * @notice Internal function to convert LP Decimals to USDC Decimals
     * @param _lpAmount the amount of LP
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToUSDCTokenDecimals(uint256 _lpAmount) internal pure returns (uint256) {
        return (_lpAmount * USDC_DECIMALS) / LP_TOKEN_DECIMALS;
    }

    function _getWithdrawalRequestById(
        bytes32 _withdrawalId
    ) internal view onlyProxyContext returns (WithdrawRequest memory) {
        return s_withdrawRequests[_withdrawalId];
    }

    function getWithdrawalIdByLPAddress(address _lpAddress) external view returns (bytes32) {
        return s_withdrawalIdByLPAddress[_lpAddress];
    }

    function getMaxDeposit() external view returns (uint256) {
        return s_maxDeposit;
    }

    function getUsdcInUse() external view returns (uint256) {
        return s_loansInUse;
    }

    function getDepositsOnTheWay()
        external
        view
        returns (DepositOnTheWay[MAX_DEPOSITS_ON_THE_WAY_COUNT] memory)
    {
        return s_depositsOnTheWayArray;
    }

    function getPendingRequests() external view returns (bytes32[] memory _requests) {
        _requests = s_withdrawalRequestIds;
    }

    function getPendingWithdrawRequestsLength() public view returns (uint256) {
        return s_withdrawalRequestIds.length;
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
    function setConceroContractSender(
        uint64 _chainSelector,
        address _contractAddress,
        uint256 _isAllowed
    ) external payable onlyProxyContext onlyOwner {
        if (_contractAddress == address(0)) revert InvalidAddress();
        s_contractsToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

        emit ConceroParentPool_ConceroSendersUpdated(_chainSelector, _contractAddress, _isAllowed);
    }

    function deleteDepositsOnTheWayByIds(bytes1[] calldata _ids) external onlyOwner {
        _deleteDepositsOnTheWayByIndexes(_ids);
    }

    /**
     * @notice Function to set the Cap of the Master pool.
     * @param _newCap The new Cap of the pool
     */
    function setPoolCap(uint256 _newCap) external payable onlyProxyContext onlyOwner {
        s_maxDeposit = _newCap;

        emit ConceroParentPool_MasterPoolCapUpdated(_newCap);
    }

    function setDonHostedSecretsSlotId(uint8 _slotId) external payable onlyProxyContext onlyOwner {
        s_donHostedSecretsSlotId = _slotId;
        emit ConceroParentPool_DonHostedSlotId(_slotId);
    }

    /**
     * @notice Function to set the Don Secrets Version from Chainlink Functions
     * @param _version the version
     * @dev this functions was used inside of ConceroFunctions
     */
    function setDonHostedSecretsVersion(
        uint64 _version
    ) external payable onlyProxyContext onlyOwner {
        s_donHostedSecretsVersion = _version;
        emit ConceroParentPool_DonSecretVersionUpdated(_version);
    }

    /**
     * @notice Function to set the Source JS code for Chainlink Functions
     * @param _hashSum  the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setCollectLiquidityJsCodeHashSum(
        bytes32 _hashSum
    ) external payable onlyProxyContext onlyOwner {
        s_collectLiquidityJsCodeHashSum = _hashSum;
    }

    function setDistributeLiquidityJsCodeHashSum(
        bytes32 _hashSum
    ) external payable onlyProxyContext onlyOwner {
        s_distributeLiquidityJsCodeHashSum = _hashSum;
    }

    /**
     * @notice Function to set the Ethers JS code for Chainlink Functions
     * @param _ethersHashSum the JsCode
     * @dev this functions was used inside of ConceroFunctions
     */
    function setEthersHashSum(bytes32 _ethersHashSum) external payable onlyProxyContext onlyOwner {
        s_ethersHashSum = _ethersHashSum;
    }

    /**
     * @notice function to manage the Cross-chain ConceroPool contracts
     * @param _chainSelector chain identifications
     * @param _pool address of the Cross-chain ConceroPool contract
     * @dev only owner can call it
     * @dev it's payable to save some gas.
     * @dev this functions is used on ConceroPool.sol
     */
    function setPools(
        uint64 _chainSelector,
        address _pool,
        bool isRebalancingNeeded
    ) external payable onlyProxyContext onlyOwner {
        if (s_childPools[_chainSelector] == _pool || _pool == address(0)) {
            revert InvalidAddress();
        }

        s_poolChainSelectors.push(_chainSelector);
        s_childPools[_chainSelector] = _pool;

        emit ConceroParentPool_PoolReceiverUpdated(_chainSelector, _pool);

        if (isRebalancingNeeded == true) {
            bytes32 distributeLiquidityRequestId = keccak256(
                abi.encodePacked(
                    _pool,
                    _chainSelector,
                    DistributeLiquidityType.addPool,
                    block.timestamp,
                    block.number,
                    block.prevrandao
                )
            );

            bytes[] memory args = new bytes[](6);
            args[0] = abi.encodePacked(s_distributeLiquidityJsCodeHashSum);
            args[1] = abi.encodePacked(s_ethersHashSum);
            args[2] = abi.encodePacked(FunctionsRequestType.distributeLiquidity);
            args[3] = abi.encodePacked(_chainSelector);
            args[4] = abi.encodePacked(distributeLiquidityRequestId);
            args[5] = abi.encodePacked(DistributeLiquidityType.addPool);

            bytes32 requestId = _sendRequest(args, JS_CODE);

            emit ConceroParentPool_RedistributionStarted(requestId);
        }
    }

    /**
     * @notice Function to remove Cross-chain address disapproving transfers
     * @param _chainSelector the CCIP chainSelector for the specific chain
     */
    function removePools(uint64 _chainSelector) external payable onlyProxyContext onlyOwner {
        address removedPool;
        for (uint256 i; i < s_poolChainSelectors.length; ) {
            if (s_poolChainSelectors[i] == _chainSelector) {
                removedPool = s_childPools[_chainSelector];
                s_poolChainSelectors[i] = s_poolChainSelectors[s_poolChainSelectors.length - 1];
                s_poolChainSelectors.pop();
                delete s_childPools[_chainSelector];
            }
            unchecked {
                ++i;
            }
        }

        bytes32 distributeLiquidityRequestId = keccak256(
            abi.encodePacked(
                removedPool,
                _chainSelector,
                DistributeLiquidityType.removePool,
                block.timestamp,
                block.number,
                block.prevrandao
            )
        );

        bytes[] memory args = new bytes[](6);
        args[0] = abi.encodePacked(s_distributeLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(FunctionsRequestType.distributeLiquidity);
        args[3] = abi.encodePacked(_chainSelector);
        args[4] = abi.encodePacked(distributeLiquidityRequestId);
        args[5] = abi.encodePacked(DistributeLiquidityType.removePool);

        bytes32 requestId = _sendRequest(args, JS_CODE);

        emit ConceroParentPool_RedistributionStarted(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                          AUTOMATION EXTERNAL
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to add new withdraw request to CLA monitoring system
     * @param _withdrawalId the ID of the withdrawal request
     * @dev this function should only be called by the ConceroPool.sol
     */
    function _addPendingWithdrawalId(bytes32 _withdrawalId) internal {
        s_withdrawalRequestIds.push(_withdrawalId);
        emit ConceroParentPool_RequestAdded(_withdrawalId);
    }

    /**
     * @notice Chainlink Automation Function to check for requests with fulfilled conditions
     * We don't use the calldata
     * @return _upkeepNeeded it will return true, if the time condition is reached
     * @return _performData the payload we need to send through performUpkeep to Chainlink functions.
     * @dev this function must only be simulated offchain by Chainlink Automation nodes
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override cannotExecute returns (bool, bytes memory) {
        uint256 withdrawalRequestsCount = s_withdrawalRequestIds.length;

        for (uint256 i; i < withdrawalRequestsCount; ++i) {
            bytes32 withdrawalId = s_withdrawalRequestIds[i];

            WithdrawRequest memory withdrawalRequest = _getWithdrawalRequestById(withdrawalId);

            address lpAddress = withdrawalRequest.lpAddress;
            uint256 amountToWithdraw = withdrawalRequest.amountToWithdraw;
            uint256 liquidityRequestedFromEachPool = withdrawalRequest
                .liquidityRequestedFromEachPool;

            if (amountToWithdraw == 0) {
                continue;
            }
            // s_withdrawTriggered is used to prevent multiple CLA triggers of the same withdrawal request
            if (
                s_withdrawTriggered[withdrawalId] == false &&
                block.timestamp > withdrawalRequest.triggeredAtTimestamp
            ) {
                bytes memory _performData = abi.encode(
                    lpAddress,
                    liquidityRequestedFromEachPool,
                    withdrawalId
                );
                bool _upkeepNeeded = true;
                return (_upkeepNeeded, _performData);
            }
        }
        return (false, "");
    }

    /**
     * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
     * @param _performData the performData encoded in checkUpkeep function
     * @dev this function must be called only by the Chainlink Forwarder unique address
     */
    function performUpkeep(bytes calldata _performData) external override {
        if (msg.sender != i_automationForwarder)
            revert ConceroParentPool_CallerNotAllowed(msg.sender);
        (address lpAddress, uint256 liquidityRequestedFromEachPool, bytes32 withdrawalId) = abi
            .decode(_performData, (address, uint256, bytes32));

        if (s_withdrawTriggered[withdrawalId] == true) {
            revert ConceroParentPool_WithdrawAlreadyTriggered(withdrawalId);
        } else {
            s_withdrawTriggered[withdrawalId] = true;
        }

        bytes[] memory args = new bytes[](5);
        args[0] = abi.encodePacked(s_collectLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(lpAddress);
        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
        args[4] = abi.encodePacked(withdrawalId);

        bytes32 reqId = _sendRequest(args, JS_CODE);
        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;
        s_clfRequestTypes[reqId] = RequestType.performUpkeep_requestLiquidityTransfer;

        _addWithdrawalOnTheWayAmountById(withdrawalId);
        emit ConceroParentPool_UpkeepPerformed(reqId);
    }

    function retryPerformWithdrawalRequest() external {
        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];
        WithdrawRequest memory withdrawalRequest = _getWithdrawalRequestById(withdrawalId);

        uint256 amountToWithdraw = withdrawalRequest.amountToWithdraw;
        address lpAddress = withdrawalRequest.lpAddress;
        uint256 liquidityRequestedFromEachPool = withdrawalRequest.liquidityRequestedFromEachPool;
        uint256 triggeredAtTimestamp = withdrawalRequest.triggeredAtTimestamp;

        if (msg.sender != lpAddress) revert ConceroParentPool_CallerNotAllowed(msg.sender);

        if (amountToWithdraw == 0) {
            revert ConceroParentPool_WithdrawRequestDoesntExist(withdrawalId);
        }

        if (block.timestamp < triggeredAtTimestamp + 30 minutes) {
            revert ConceroParentPool_WithdrawRequestNotReady(withdrawalId);
        }

        bytes[] memory args = new bytes[](5);
        args[0] = abi.encodePacked(s_collectLiquidityJsCodeHashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(lpAddress);
        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
        args[4] = abi.encodePacked(withdrawalId);

        bytes32 reqId = _sendRequest(args, JS_CODE);
        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;

        emit ConceroParentPool_RetryPerformed(reqId);
    }

    /**
     * @notice Function to send a Request to Chainlink Functions
     * @param _args the arguments for the request as bytes array
     * @param _jsCode the JScode that will be executed.
     */
    function _sendRequest(bytes[] memory _args, string memory _jsCode) internal returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(_jsCode);
        req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
        req.setBytesArgs(_args);

        return
            _sendRequest(
                req.encodeCBOR(),
                i_subscriptionId,
                CL_FUNCTIONS_CALLBACK_GAS_LIMIT,
                i_donId
            );
    }

    function calculateLpAmount(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256) {
        return _calculateLPTokensToMint(childPoolsBalance, amountToDeposit);
    }

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256) {
        return _calculateWithdrawableAmount(childPoolsBalance, clpAmount, i_lpToken.totalSupply());
    }

    ///////////////
    /// INTERNAL ///
    ///////////////

    /**
     * @notice CCIP function to receive bridged values
     * @param any2EvmMessage the CCIP message
     * @dev only allowed chains and sender must be able to deliver a message in this function.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyAllowlistedSenderOfChainSelector(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        )
    {
        // todo: this should be changed to a struct
        (address lpAddress, address user, uint256 receivedFee) = abi.decode(
            any2EvmMessage.data,
            (address, address, uint256)
        );

        bool isUserTx = receivedFee > 0 && user != address(0);
        bool isWithdrawalTx = lpAddress != address(0);

        if (isUserTx) {
            IStorage.Transaction memory transaction = IOrchestrator(i_infraProxy).getTransaction(
                any2EvmMessage.messageId
            );
            bool isExecutionLayerFailed = ((transaction.ccipMessageId == any2EvmMessage.messageId &&
                transaction.isConfirmed == false) || transaction.ccipMessageId == 0);
            if (isExecutionLayerFailed) {
                //We don't subtract fee here because the loan was not performed. And the value is not summed into the `s_loanInUse` variable.
                i_USDC.safeTransfer(user, any2EvmMessage.destTokenAmounts[0].amount);
            } else {
                //subtract the amount from the committed total amount
                uint256 amountAfterFees = (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);
                s_loansInUse -= amountAfterFees;
            }
        } else if (isWithdrawalTx) {
            bytes32 withdrawalId = s_withdrawalIdByLPAddress[lpAddress];
            if (withdrawalId == bytes32(0)) revert ConceroParentPool_RequestDoesntExist();
            WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

            request.remainingLiquidityFromChildPools = request.remainingLiquidityFromChildPools >=
                any2EvmMessage.destTokenAmounts[0].amount
                ? request.remainingLiquidityFromChildPools -
                    any2EvmMessage.destTokenAmounts[0].amount
                : 0;

            s_withdrawalsOnTheWayAmount = s_withdrawalsOnTheWayAmount >=
                any2EvmMessage.destTokenAmounts[0].amount
                ? s_withdrawalsOnTheWayAmount - any2EvmMessage.destTokenAmounts[0].amount
                : 0;

            s_withdrawAmountLocked += any2EvmMessage.destTokenAmounts[0].amount;
        }

        emit ConceroParentPool_CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts[0].amount
        );
    }

    /**
     * @notice helper function to distribute liquidity after LP deposits.
     * @param _usdcAmountToDeposit amount of USDC should be distributed to the pools.
     */
    function _distributeLiquidityToChildPools(uint256 _usdcAmountToDeposit) internal {
        uint256 childPoolsCount = s_poolChainSelectors.length;
        uint256 amountToDistribute = ((_usdcAmountToDeposit * PRECISION_HANDLER) /
            (childPoolsCount + 1)) / PRECISION_HANDLER;

        for (uint256 i; i < childPoolsCount; ) {
            bytes32 ccipMessageId = _ccipSend(s_poolChainSelectors[i], amountToDistribute);
            _addDepositOnTheWay(ccipMessageId, s_poolChainSelectors[i], amountToDistribute);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Function to distribute funds automatically right after LP deposits into the pool
     * @dev this function will only be called internally.
     */
    function _ccipSend(
        uint64 _chainSelector,
        uint256 _amountToDistribute
    ) internal returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _chainSelector,
            address(i_USDC),
            _amountToDistribute
        );

        uint256 ccipFeeAmount = IRouterClient(i_ccipRouter).getFee(_chainSelector, evm2AnyMessage);

        i_USDC.approve(i_ccipRouter, _amountToDistribute);
        i_linkToken.approve(i_ccipRouter, ccipFeeAmount);

        messageId = IRouterClient(i_ccipRouter).ccipSend(_chainSelector, evm2AnyMessage);

        emit ConceroParentPool_CCIPSent(messageId, _chainSelector, s_childPools[_chainSelector]);
    }

    function _buildCCIPMessage(
        uint64 _chainSelector,
        address _token,
        uint256 _amount
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(s_childPools[_chainSelector]),
                data: abi.encode(address(0), address(0), 0), //Here the 1° address is (0) because this is the Parent Pool and we never send to withdraw in another place.
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 350_000})),
                feeToken: address(i_linkToken)
            });
    }

    /// @dev taken from the ConceroAutomation::fulfillRequest logic
    function _handleAutomationCLFFulfill(bytes32 _requestId, bytes memory _response) internal {
        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[_requestId];

        for (uint256 i; i < s_withdrawalRequestIds.length; ++i) {
            if (s_withdrawalRequestIds[i] == withdrawalId) {
                s_withdrawalRequestIds[i] = s_withdrawalRequestIds[
                    s_withdrawalRequestIds.length - 1
                ];
                s_withdrawalRequestIds.pop();
            }
        }
    }

    /**
     * @notice Function called by Chainlink Functions fulfillRequest to update deposit information
     * @param _childPoolBalance The total cross chain balance of child pools
     * @param _amountToDeposit the amount of USDC deposited
     * @dev This function must be called only by an allowed Messenger & must not revert
     * @dev _totalUSDCCrossChainBalance MUST have 10**6 decimals.
     */
    function _calculateLPTokensToMint(
        uint256 _childPoolBalance,
        uint256 _amountToDeposit
    ) private view returns (uint256) {
        uint256 parentPoolLiquidity = i_USDC.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        //todo: we must add withdrawalsOnTheWay

        uint256 totalCrossChainLiquidity = _childPoolBalance + parentPoolLiquidity;
        uint256 crossChainBalanceConverted = _convertToLPTokenDecimals(totalCrossChainLiquidity);
        uint256 amountDepositedConverted = _convertToLPTokenDecimals(_amountToDeposit);
        uint256 _totalLPSupply = i_lpToken.totalSupply();

        //N° lpTokens = (((Total USDC Liq + user deposit) * Total sToken) / Total USDC Liq) - Total sToken
        uint256 lpTokensToMint;

        if (_totalLPSupply != 0) {
            lpTokensToMint =
                (((crossChainBalanceConverted + amountDepositedConverted) * _totalLPSupply) /
                    crossChainBalanceConverted) -
                _totalLPSupply;
        } else {
            lpTokensToMint = amountDepositedConverted;
        }
        return lpTokensToMint;
    }

    function _calculateWithdrawableAmount(
        uint256 _childPoolsBalance,
        uint256 _clpAmount,
        uint256 _lpSupply
    ) internal view returns (uint256) {
        uint256 parentPoolLiquidity = i_USDC.balanceOf(address(this)) +
            s_loansInUse +
            s_depositsOnTheWayAmount -
            s_depositFeeAmount;
        uint256 totalCrossChainLiquidity = _childPoolsBalance + parentPoolLiquidity;

        //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
        uint256 amountUsdcToWithdraw = (((_convertToLPTokenDecimals(totalCrossChainLiquidity) *
            _clpAmount) * PRECISION_HANDLER) / _lpSupply) / PRECISION_HANDLER;

        return _convertToUSDCTokenDecimals(amountUsdcToWithdraw);
    }

    function _addDepositOnTheWay(
        bytes32 _ccipMessageId,
        uint64 _chainSelector,
        uint256 _amount
    ) internal {
        uint8 index = s_latestDepositOnTheWayIndex < (MAX_DEPOSITS_ON_THE_WAY_COUNT - 1)
            ? ++s_latestDepositOnTheWayIndex
            : _findLowestDepositOnTheWayUnusedIndex();

        s_depositsOnTheWayArray[index] = DepositOnTheWay({
            ccipMessageId: _ccipMessageId,
            chainSelector: _chainSelector,
            amount: _amount
        });

        s_depositsOnTheWayAmount += _amount;
    }

    function _findLowestDepositOnTheWayUnusedIndex() internal returns (uint8) {
        uint8 index;
        for (uint8 i = 1; i < MAX_DEPOSITS_ON_THE_WAY_COUNT; ) {
            if (s_depositsOnTheWayArray[i].ccipMessageId == bytes32(0)) {
                index = i;
                s_latestDepositOnTheWayIndex = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (index == 0) {
            revert ConceroParentPool_DepositsOnTheWayArrayFull();
        }

        return index;
    }

    function _addWithdrawalOnTheWayAmountById(bytes32 _withdrawalId) internal {
        uint256 amountToWithdraw = s_withdrawRequests[_withdrawalId].amountToWithdraw -
            s_withdrawRequests[_withdrawalId].liquidityRequestedFromEachPool;

        if (amountToWithdraw == 0) revert ConceroParentPool_RequestDoesntExist();

        s_withdrawalsOnTheWayAmount += amountToWithdraw;
    }

    // function _calculateDepositTransactionFee(uint256 _amountToDistribute) internal view returns(uint256 _totalUSDCCost){
    //   uint256 numberOfPools = s_poolChainSelectors.length;
    //   uint256 costOfLinkForLiquidityDistribution;
    //   uint256 premiumFee = Orchestrator(i_infraProxy).clfPremiumFees(BASE_CHAIN_SELECTOR);
    //   uint256 lastNativeUSDCRate = Orchestrator(i_infraProxy).s_latestNativeUsdcRate();
    //   uint256 lastLinkUSDCRate = Orchestrator(i_infraProxy).s_latestLinkUsdcRate();
    //   uint256 lastBaseGasPrice = tx.gasprice; //Orchestrator(i_infraProxy).s_lastGasPrices(BASE_CHAIN_SELECTOR);

    //   for(uint256 i; i < numberOfPools; ){
    //     Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), (_amountToDistribute / (numberOfPools+1)), s_childPools[s_poolChainSelectors[i]]);

    //     //Link cost for all transactions
    //     costOfLinkForLiquidityDistribution += IRouterClient(i_ccipRouter).getFee(s_poolChainSelectors[i], evm2AnyMessage);
    //     unchecked {
    //       ++i;
    //     }
    //   }

    //   //_totalUSDCCost
    //   //    Pools.length x Calls to distribute liquidity
    //   //    1x Functions request sent
    //   //    1x Callback Writing to storage
    //   _totalUSDCCost = ((costOfLinkForLiquidityDistribution + premiumFee) * lastLinkUSDCRate) + ((WRITE_FUNCTIONS_COST * lastBaseGasPrice) * lastNativeUSDCRate);
    // }

    // function _calculateWithdrawTransactionsFee(uint256 _amountToReceive) internal view returns(uint256 _totalUSDCCost){
    //   uint256 numberOfPools = s_poolChainSelectors.length;
    //   uint256 premiumFee = Orchestrator(i_infraProxy).clfPremiumFees(BASE_CHAIN_SELECTOR);
    //   uint256 baseLastGasPrice = tx.gasprice; //Orchestrator(i_infraProxy).s_lastGasPrices(BASE_CHAIN_SELECTOR);
    //   uint256 lastNativeUSDCRate = Orchestrator(i_infraProxy).s_latestNativeUsdcRate();
    //   uint256 lastLinkUSDCRate = Orchestrator(i_infraProxy).s_latestLinkUsdcRate();

    //   uint256 costOfLinkForLiquidityWithdraw;
    //   uint256 costOfCCIPSendToPoolExecution;

    //   for(uint256 i; i < numberOfPools; ){
    //     Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), _amountToReceive, address(this));

    //     //Link cost for all transactions
    //     costOfLinkForLiquidityWithdraw += IRouterClient(i_ccipRouter).getFee(BASE_CHAIN_SELECTOR, evm2AnyMessage); //here the chainSelector must be Base's?
    //     //USDC costs for all writing from the above transactions
    //     costOfCCIPSendToPoolExecution += Orchestrator(i_infraProxy).s_lastGasPrices(s_poolChainSelectors[i]) * WRITE_FUNCTIONS_COST;
    //     unchecked {
    //       ++i;
    //     }
    //   }

    //   // _totalUSDCCost ==
    //   //    2x Functions Calls - Link Cost
    //   //    Pools.length x Calls - Link Cost
    //   //    Base's gas Cost of callback
    //   //    Pools.length x Calls to ccipSendToPool Child Pool function
    //   //  Automation Costs?
    //   //    SLOAD - 2100
    //   //    ++i - 5
    //   //    Comparing = 3
    //   //    STORE - 5_000
    //   //    Array Reduction - 5_000
    //   //    gasOverhead - 80_000
    //   //    Nodes Premium - 50%
    //   uint256 arrayLength = i_automation.getPendingWithdrawRequestsLength();

    //   uint256 automationCost = (((CLA_PERFORMUPKEEP_ITERATION_GAS_COSTS * arrayLength) + ARRAY_MANIPULATION + AUTOMATION_OVERHEARD) * NODE_PREMIUM) / 100;
    //   _totalUSDCCost = (((premiumFee * 2) + costOfLinkForLiquidityWithdraw + automationCost) * lastLinkUSDCRate) + ((WRITE_FUNCTIONS_COST * baseLastGasPrice) * lastNativeUSDCRate) + costOfCCIPSendToPoolExecution;
    // }
}
