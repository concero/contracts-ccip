// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "./BaseTest.t.sol";
import {DepositTest} from "./Deposit.t.sol";
import {ParentPool_Wrapper, IParentPoolWrapper} from "./wrappers/ParentPool_Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ConceroParentPool_AmountBelowMinimum} from "contracts/ConceroParentPool.sol";
import {FunctionsRouter, IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {
    FunctionsCoordinator,
    FunctionsBillingConfig
} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract WithdrawTest is DepositTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant WITHDRAW_AMOUNT_LP =
        ((DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC) * WAD_PRECISION) / USDC_PRECISION;
    uint256 internal constant PRECISION_HANDLER = 10_000_000_000;
    uint256 internal constant WITHDRAW_DEADLINE_SECONDS = 597_600;
    uint256 internal constant MIN_WITHDRAW = 1e18;

    address forwarder = makeAddr("forwarder");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        DepositTest.setUp();

        /// @dev set CLA forwarder address
        vm.prank(deployer);
        (bool success,) =
            address(parentPoolProxy).call(abi.encodeWithSignature("setForwarderAddress(address)", forwarder));
        require(success, "setForwarderAddress call failed");

        /// @dev fund functions subscription
        _fundFunctionsSubscription();
    }

    /*//////////////////////////////////////////////////////////////
                            START WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function test_startWithdrawal_success() public {
        /// @dev deposit
        _startAndCompleteDeposit(user1, DEPOSIT_AMOUNT_USDC, INITIAL_DIRECT_DEPOSIT);

        /// @dev startWithdrawal
        _startWithdrawalAndMonitorLogs(user1, WITHDRAW_AMOUNT_LP);

        /// @dev get withdrawalId
        bytes32 withdrawalId = _getWithdrawalId(user1);

        /// @dev use withdrawalId to get request params
        (, bytes memory returnParams) =
            address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalId));
        (address lpAddress, uint256 lpSupplySnapshot, uint256 lpAmountToBurn,,,,,) =
            abi.decode(returnParams, (address, uint256, uint256, uint256, uint256, uint256, uint256, uint256));

        assertEq(lpAddress, user1);
        assertEq(lpSupplySnapshot, IERC20(parentPoolImplementation.i_lp()).totalSupply());
        assertEq(lpAmountToBurn, WITHDRAW_AMOUNT_LP);
    }

    function _startWithdrawalAndMonitorLogs(address _caller, uint256 _amount)
        internal
        returns (bytes32 requestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels)
    {
        /// @dev record the logs so we can find the CLF request ID
        vm.recordLogs();

        /// @dev approve the pool to spend LP tokens
        vm.startPrank(_caller);
        IERC20(parentPoolImplementation.i_lp()).approve(address(parentPoolProxy), _amount);

        /// @dev call startWithdrawal via proxy
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", _amount));
        require(success, "startWithdrawal call failed");
        vm.stopPrank();

        /// @dev get and verify logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 6);
        /// @dev find the RequestStart log and params we need for commitment
        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].topics[0]
                    == keccak256("RequestStart(bytes32,bytes32,uint64,address,address,address,bytes,uint16,uint32,uint96)")
            ) {
                /// @dev get the values we need
                requestId = entries[i].topics[1];
                (,,,,, callbackGasLimit, estimatedTotalCostJuels) =
                    abi.decode(entries[i].data, (address, address, address, bytes, uint16, uint32, uint96));
                break;
            }
        }

        return (requestId, callbackGasLimit, estimatedTotalCostJuels);
    }

    function test_startWithdrawal_reverts_if_zero_lpAmount() public {
        /// @dev expect startWithdrawal to revert with 0 lpAmount
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_AmountBelowMinimum(uint256)", 1));
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", 0));
    }

    function test_startWithdrawal_reverts_if_request_already_active() public {
        /// @dev startDeposit
        (bytes32 depositRequestId, uint32 depositCallbackGasLimit, uint96 depositEstimatedTotalCostJuels) =
            _startDepositAndMonitorLogs(user1, DEPOSIT_AMOUNT_USDC);

        /// @dev fulfill active request
        bytes memory response = abi.encode(INITIAL_DIRECT_DEPOSIT); // 1 usdc
        _fulfillRequest(response, depositRequestId, depositCallbackGasLimit, depositEstimatedTotalCostJuels);

        /// @dev completeDeposit
        _completeDeposit(user1, depositRequestId);

        /// @dev approve the pool to spend LP tokens
        vm.startPrank(user1);
        IERC20(parentPoolImplementation.i_lp()).approve(address(parentPoolProxy), WITHDRAW_AMOUNT_LP);

        /// @dev call startWithdrawal via proxy
        (bool success,) =
            address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", WITHDRAW_AMOUNT_LP));
        require(success, "Function call failed");

        /// @dev call again, expecting revert
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_ActiveRequestNotFulfilledYet()"));
        (bool success2,) =
            address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", WITHDRAW_AMOUNT_LP));
        vm.stopPrank();
    }

    function test_startWithdrawal_reverts_if_not_proxy_caller(address _caller) public {
        /// @dev expect revert when calling startWithdrawal directly
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature("ConceroParentPool_NotParentPoolProxy(address)", address(parentPoolImplementation))
        );
        parentPoolImplementation.startWithdrawal(WITHDRAW_AMOUNT_LP);
    }

    /*//////////////////////////////////////////////////////////////
                          COMPLETE WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function test_completeWithdrawal_success() public {
        /// @dev deposit
        _startAndCompleteDeposit(user1, DEPOSIT_AMOUNT_USDC, INITIAL_DIRECT_DEPOSIT);

        /// @dev startWithdrawal
        (bytes32 withdrawalRequestId, uint32 withdrawalCallbackGasLimit, uint96 withdrawalEstimatedTotalCostJuels) =
            _startWithdrawalAndMonitorLogs(user1, WITHDRAW_AMOUNT_LP / 2);

        /// @dev fulfill active withdrawal request
        bytes memory withdrawResponse = abi.encode(INITIAL_DIRECT_DEPOSIT + (DEPOSIT_AMOUNT_USDC / 2)); // 1 usdc + (first deposit / parent+child)
        _fulfillRequest(
            withdrawResponse, withdrawalRequestId, withdrawalCallbackGasLimit, withdrawalEstimatedTotalCostJuels
        );

        /// @dev get the withdrawalId before completing withdrawal
        bytes32 withdrawalIdBeforeComplete = _getWithdrawalId(user1);
        /// @dev get balances before completing withdrawal
        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(user1);
        uint256 lpTotalSupplyBefore = IERC20(address(lpToken)).totalSupply();
        /// @dev get the amount we expect to withdraw
        (,, uint256 expectedLpAmountToBurn,, uint256 expectedAmountToWithdraw,,,) =
            IParentPoolWrapper(address(parentPoolProxy)).getWithdrawRequestParams(withdrawalIdBeforeComplete);

        /// @dev completeWithdrawal
        _completeWithdrawal(user1, WITHDRAW_AMOUNT_LP / 2);

        /// @dev assert LP tokens burned
        uint256 lpTotalSupplyAfter = IERC20(address(lpToken)).totalSupply();
        assertEq(expectedLpAmountToBurn, lpTotalSupplyBefore - lpTotalSupplyAfter);

        /// @dev assert we got the right amount of usdc
        uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(user1);
        assertEq(expectedAmountToWithdraw, usdcBalanceAfter - usdcBalanceBefore);

        /// @dev assert storage updated
        (
            address lpAddress,
            uint256 lpSupplySnapshot,
            uint256 lpAmountToBurn,
            uint256 totalCrossChainLiquiditySnapshot,
            uint256 amountToWithdraw,
            uint256 liquidityRequestedFromEachPool,
            ,
        ) = IParentPoolWrapper(address(parentPoolProxy)).getWithdrawRequestParams(withdrawalIdBeforeComplete);
        assertEq(lpAddress, address(0));
        assertEq(lpSupplySnapshot, 0);
        assertEq(lpAmountToBurn, 0);
        assertEq(totalCrossChainLiquiditySnapshot, 0);
        assertEq(amountToWithdraw, 0);
        assertEq(liquidityRequestedFromEachPool, 0);

        bytes32 withdrawalIdAfterComplete = _getWithdrawalId(user1);
        assertEq(withdrawalIdAfterComplete, 0);

        /// @notice the user is able to create a new withdrawalRequest successfully afterwards

        /// @dev startWithdrawal
        _startWithdrawalAndMonitorLogs(user1, WITHDRAW_AMOUNT_LP / 2);

        /// @dev get withdrawalId
        bytes32 withdrawalIdRequest2 = _getWithdrawalId(user1);

        /// @dev use withdrawalId to get request params
        (, bytes memory returnParams) = address(parentPoolProxy).call(
            abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalIdRequest2)
        );
        (address lpAddressRequest2, uint256 lpSupplySnapshotRequest2, uint256 lpAmountToBurnRequest2,,,,,) =
            abi.decode(returnParams, (address, uint256, uint256, uint256, uint256, uint256, uint256, uint256));

        assertEq(lpAddressRequest2, user1);
        assertEq(lpSupplySnapshotRequest2, IERC20(parentPoolImplementation.i_lp()).totalSupply());
        assertEq(lpAmountToBurnRequest2, WITHDRAW_AMOUNT_LP / 2);
    }

    function _completeWithdrawal(address _caller, uint256 _amount) internal {
        /// @dev get withdrawalId
        bytes32 withdrawalId = _getWithdrawalId(_caller);

        /// @dev use withdrawalId to get request params
        (, bytes memory withdrawRequestParams) =
            address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalId));
        (address lpAddress,,,, uint256 amountToWithdraw, uint256 liquidityRequestedFromEachPool,,) =
            abi.decode(withdrawRequestParams, (address, uint256, uint256, uint256, uint256, uint256, uint256, uint256));
        assertGt(amountToWithdraw, 0);

        /// @dev skip time to after the withdrawal cool-off period
        vm.warp(block.timestamp + 7 days + 1);

        /// @dev mock chainlink automation by calling performUpkeep as forwarder
        bytes memory performData = abi.encode(lpAddress, liquidityRequestedFromEachPool, withdrawalId);
        vm.prank(forwarder);
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("performUpkeep(bytes)", performData));
        require(success, "performUpkeep call failed");

        /// @dev create the ccip message
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: address(usdc), amount: _amount / 2});
        tokenAmounts[0] = tokenAmount;

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage(
            keccak256("dummy messageId"), // messageId
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")), // sourceChainSelector
            abi.encode(user1), // sender
            abi.encode(lpAddress, address(0), 0), // data
            tokenAmounts
        );

        /// @dev prank the router to call ccipReceive on parentPool
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));
        IParentPoolWrapper(address(parentPoolProxy)).ccipReceive(message);
        /// @dev deal the usdc we should have received through ccip
        deal(usdc, address(parentPoolProxy), _amount / 2);

        /// @dev call the completeWithdrawal
        vm.prank(_caller);
        (bool completeWithdrawalSuccess,) =
            address(parentPoolProxy).call(abi.encodeWithSignature("completeWithdrawal()"));
        require(completeWithdrawalSuccess, "completeWithdrawal call failed");
    }

    /// @dev expect revert when calling completeWithdrawal directly
    function test_completeWithdrawal_reverts_if_not_proxy_caller(address _caller) public {
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature("ConceroParentPool_NotParentPoolProxy(address)", address(parentPoolImplementation))
        );
        parentPoolImplementation.completeWithdrawal();
    }

    /// @dev expect revert when withdrawalId doesn't exist
    function test_completeWithdrawal_reverts_if_withdrawalId_doesnt_exist(address _caller) public {
        vm.prank(_caller);
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_RequestDoesntExist()"));
        address(parentPoolProxy).call(abi.encodeWithSignature("completeWithdrawal()"));
    }

    function test_completeWithdrawal_reverts_if_withdrawal_amount_not_ready() public {
        /// @dev deposit
        _startAndCompleteDeposit(user1, DEPOSIT_AMOUNT_USDC, INITIAL_DIRECT_DEPOSIT);

        /// @dev startWithdrawal
        (bytes32 withdrawalRequestId, uint32 withdrawalCallbackGasLimit, uint96 withdrawalEstimatedTotalCostJuels) =
            _startWithdrawalAndMonitorLogs(user1, WITHDRAW_AMOUNT_LP / 2);

        /// @dev fulfill active withdrawal request
        bytes memory withdrawResponse = abi.encode(INITIAL_DIRECT_DEPOSIT + (DEPOSIT_AMOUNT_USDC / 2)); // 1 usdc + (first deposit / parent+child)
        _fulfillRequest(
            withdrawResponse, withdrawalRequestId, withdrawalCallbackGasLimit, withdrawalEstimatedTotalCostJuels
        );

        /// @dev get withdrawalId
        bytes32 withdrawalId = _getWithdrawalId(user1);

        /// @dev use withdrawalId to get request params
        (, bytes memory withdrawRequestParams) =
            address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalId));
        (,,,,,, uint256 remainingLiquidityFromChildPools,) =
            abi.decode(withdrawRequestParams, (address, uint256, uint256, uint256, uint256, uint256, uint256, uint256));

        /// @dev expect revert when withdrawal amount not ready
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ConceroParentPool_WithdrawalAmountNotReady(uint256)", remainingLiquidityFromChildPools
            )
        );
        address(parentPoolProxy).call(abi.encodeWithSignature("completeWithdrawal()"));
    }

    /*//////////////////////////////////////////////////////////////
                           LP TOKEN ISSUANCE
    //////////////////////////////////////////////////////////////*/
    function test_lpToken_integrity_deposits_and_withdrawals_on_the_way(uint256 _amount1, uint256 _amount2) public {
        /// @dev restrict fuzzed deposit amounts
        _amount1 = bound(_amount1, MIN_DEPOSIT + DEPOSIT_FEE_USDC, MAX_INDIVIDUAL_DEPOSIT);
        _amount2 = bound(_amount2, MIN_DEPOSIT + DEPOSIT_FEE_USDC, MAX_INDIVIDUAL_DEPOSIT);

        /// @dev start and complete deposit for user1
        _startAndCompleteDeposit(user1, _amount1, INITIAL_DIRECT_DEPOSIT);

        /// @dev startWithdrawal and fulfillRequest for user1
        _startWithdrawalAndFulfillRequest(
            user1, WITHDRAW_AMOUNT_LP / 2, INITIAL_DIRECT_DEPOSIT + (DEPOSIT_AMOUNT_USDC / 2)
        ); // 1 usdc + (first deposit / parent+child)

        /// @dev use withdrawalId to get request params
        (, bytes memory withdrawRequestParams) = address(parentPoolProxy).call(
            abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", _getWithdrawalId(user1))
        );
        (address lpAddress,,,,, uint256 liquidityRequestedFromEachPool,,) =
            abi.decode(withdrawRequestParams, (address, uint256, uint256, uint256, uint256, uint256, uint256, uint256));

        /// @dev mock chainlink automation by calling performUpkeep as forwarder
        bytes memory performData = abi.encode(lpAddress, liquidityRequestedFromEachPool, _getWithdrawalId(user1));
        vm.prank(forwarder);
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("performUpkeep(bytes)", performData));
        require(success, "performUpkeep call failed");

        /// @dev assert s_depositsOnTheWayAmount is more than 0
        assertGt(IParentPoolWrapper(address(parentPoolProxy)).getDepositsOnTheWayAmount(), 0);
        /// @dev assert s_withdrawalsOnTheWayAmount is more than 0
        assertGt(IParentPoolWrapper(address(parentPoolProxy)).getWithdrawalsOnTheWayAmount(), 0);

        /// @dev we need the totalSupply to calculate user2's owed lp tokens
        uint256 lpTotalSupplyBeforeSecondDeposit = IERC20(parentPoolImplementation.i_lp()).totalSupply();

        /// @dev startDeposit and fulfillRequest for second user
        bytes32 depositRequestId2 =
            _startDepositAndFulfillRequest(user2, _amount2, INITIAL_DIRECT_DEPOSIT + (_amount1 / 2));

        /// @dev get the depositRequest for user2 to get childPoolsLiquiditySnapshot
        ParentPool_Wrapper.DepositRequest memory depositRequest =
            IParentPoolWrapper(address(parentPoolProxy)).getDepositRequest(depositRequestId2);

        /// @dev calculate totalCrossChainLiquidity
        uint256 totalCrossChainLiquidity =
            _calculateTotalCrossChainLiquidity(depositRequest.childPoolsLiquiditySnapshot);

        /// @dev completeDeposit for second user
        _completeDeposit(user2, depositRequestId2);

        /// @dev assert user2 lp tokens minted as expected
        uint256 expectedLpTokensMintedUser2 =
            _calculateExpectedLpTokensMinted(_amount2, totalCrossChainLiquidity, lpTotalSupplyBeforeSecondDeposit);
        assertEq(expectedLpTokensMintedUser2, IERC20(parentPoolImplementation.i_lp()).balanceOf(user2));
    }

    /*//////////////////////////////////////////////////////////////
                           WITHDRAWAL REQUEST
    //////////////////////////////////////////////////////////////*/
    /// todo: replace magic 2 number with number of child pools
    function test_withdrawalRequest_integrity(
        uint256 _depositAmount1,
        uint256 _depositAmount2,
        uint256 _withdrawAmount1,
        uint256 _withdrawAmount2
    ) public {
        /// @dev restrict fuzzed deposit amounts
        _depositAmount1 = bound(_depositAmount1, MIN_DEPOSIT + DEPOSIT_FEE_USDC, MAX_INDIVIDUAL_DEPOSIT);
        _depositAmount2 = bound(_depositAmount2, MIN_DEPOSIT + DEPOSIT_FEE_USDC, MAX_INDIVIDUAL_DEPOSIT);

        /// @dev start and complete deposits for multiple users
        _startAndCompleteDeposit(user1, _depositAmount1, INITIAL_DIRECT_DEPOSIT);
        _startAndCompleteDeposit(user2, _depositAmount2, INITIAL_DIRECT_DEPOSIT + (_depositAmount1 / 2)); // 1 child + 1 parent

        /// @dev restrict fuzzed withdraw amounts
        _withdrawAmount1 = bound(_withdrawAmount1, MIN_WITHDRAW, IERC20(address(lpToken)).balanceOf(user1));
        _withdrawAmount2 = bound(_withdrawAmount2, MIN_WITHDRAW, IERC20(address(lpToken)).balanceOf(user2));

        uint256 lpSupplyBeforeWithdrawRequest = IERC20(address(lpToken)).totalSupply();

        /// @dev startWithdrawalAndFulfill, for user1, passing caller, amount and crosschain liquidity amount
        uint256 withdrawRequestResponse1 = (
            IERC20(usdc).balanceOf(address(parentPoolProxy))
                - IParentPoolWrapper(address(parentPoolProxy)).getDepositFeeAmount()
        );
        _startWithdrawalAndFulfillRequest(user1, _withdrawAmount1, withdrawRequestResponse1);

        /// @dev get the withdrawRequest for user1
        ParentPool_Wrapper.WithdrawRequest memory withdrawRequest1 =
            IParentPoolWrapper(address(parentPoolProxy)).getWithdrawRequest(_getWithdrawalId(user1));

        /// @dev calculate expected values
        uint256 expectedAmountToWithdrawUser1 = (
            (_calculateTotalCrossChainLiquidity(withdrawRequestResponse1) * _withdrawAmount1)
                / lpSupplyBeforeWithdrawRequest
        );
        uint256 expectedRemainingLiquidityFromChildPools =
            (expectedAmountToWithdrawUser1 / 2) + (expectedAmountToWithdrawUser1 % 2);

        assertEq(withdrawRequest1.lpAddress, user1);
        assertEq(withdrawRequest1.lpSupplySnapshot, lpSupplyBeforeWithdrawRequest);
        assertEq(withdrawRequest1.lpAmountToBurn, _withdrawAmount1);
        assertEq(withdrawRequest1.totalCrossChainLiquiditySnapshot, 0); // not updated anywhere
        assertEq(withdrawRequest1.amountToWithdraw, expectedAmountToWithdrawUser1);
        assertEq(withdrawRequest1.liquidityRequestedFromEachPool, expectedAmountToWithdrawUser1 / 2);
        assertEq(withdrawRequest1.remainingLiquidityFromChildPools, expectedRemainingLiquidityFromChildPools);
        assertEq(withdrawRequest1.triggeredAtTimestamp, block.timestamp + WITHDRAW_DEADLINE_SECONDS);

        _performUpkeep(user1, withdrawRequestResponse1);

        /// @dev assert s_depositsOnTheWayAmount is more than 0
        assertGt(IParentPoolWrapper(address(parentPoolProxy)).getDepositsOnTheWayAmount(), 0);
        /// @dev assert s_withdrawalsOnTheWayAmount is more than 0
        assertGt(IParentPoolWrapper(address(parentPoolProxy)).getWithdrawalsOnTheWayAmount(), 0);

        uint256 lpSupplyBeforeSecondRequest = IERC20(address(lpToken)).totalSupply();
        /// @dev startWithdrawalAndFulfill for user2, passing caller, amount and crosschain liquidity amount
        uint256 withdrawRequestResponse2 = (
            IERC20(usdc).balanceOf(address(parentPoolProxy))
                - IParentPoolWrapper(address(parentPoolProxy)).getDepositFeeAmount()
        );
        _startWithdrawalAndFulfillRequest(user2, _withdrawAmount2, withdrawRequestResponse2);

        /// @dev get the withdrawRequest for user1
        ParentPool_Wrapper.WithdrawRequest memory withdrawRequest2 =
            IParentPoolWrapper(address(parentPoolProxy)).getWithdrawRequest(_getWithdrawalId(user2));

        /// @dev calculate expected values
        uint256 expectedAmountToWithdrawUser2 = (
            (_calculateTotalCrossChainLiquidity(withdrawRequestResponse2) * _withdrawAmount2)
                / lpSupplyBeforeSecondRequest
        );
        uint256 expectedRemainingLiquidityFromChildPools2 =
            (expectedAmountToWithdrawUser2 / 2) + (expectedAmountToWithdrawUser2 % 2);

        assertEq(withdrawRequest2.lpAddress, user2);
        assertEq(withdrawRequest2.lpSupplySnapshot, lpSupplyBeforeSecondRequest);
        assertEq(withdrawRequest2.lpAmountToBurn, _withdrawAmount2);
        assertEq(withdrawRequest2.totalCrossChainLiquiditySnapshot, 0); // not updated anywhere
        assertEq(withdrawRequest2.amountToWithdraw, expectedAmountToWithdrawUser2);
        assertEq(withdrawRequest2.liquidityRequestedFromEachPool, expectedAmountToWithdrawUser2 / 2);
        assertEq(withdrawRequest2.remainingLiquidityFromChildPools, expectedRemainingLiquidityFromChildPools2);
        assertEq(withdrawRequest2.triggeredAtTimestamp, block.timestamp + WITHDRAW_DEADLINE_SECONDS);
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _performUpkeep(address _lpAddress, uint256 _liquidityRequestedFromEachPool) internal {
        /// @dev mock chainlink automation by calling performUpkeep as forwarder
        bytes memory performData = abi.encode(_lpAddress, _liquidityRequestedFromEachPool, _getWithdrawalId(_lpAddress));
        vm.prank(forwarder);
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("performUpkeep(bytes)", performData));
        require(success, "performUpkeep call failed");
    }

    function _getWithdrawalId(address _lpAddress) internal returns (bytes32) {
        (, bytes memory returnData) =
            address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawalIdByLPAddress(address)", _lpAddress));
        bytes32 withdrawalId = abi.decode(returnData, (bytes32));
        return withdrawalId;
    }

    function _startAndCompleteDeposit(address _caller, uint256 _depositAmount, uint256 _depositRequestResponse)
        internal
    {
        /// @dev startDeposit
        (bytes32 depositRequestId, uint32 depositCallbackGasLimit, uint96 depositEstimatedTotalCostJuels) =
            _startDepositAndMonitorLogs(_caller, _depositAmount);

        /// @dev fulfill active request
        bytes memory response = abi.encode(_depositRequestResponse);
        _fulfillRequest(response, depositRequestId, depositCallbackGasLimit, depositEstimatedTotalCostJuels);

        /// @dev completeDeposit
        _completeDeposit(_caller, depositRequestId);
    }

    function _startDepositAndFulfillRequest(address _caller, uint256 _depositAmount, uint256 _depositRequestResponse)
        internal
        returns (bytes32)
    {
        /// @dev startDeposit
        (bytes32 depositRequestId, uint32 depositCallbackGasLimit, uint96 depositEstimatedTotalCostJuels) =
            _startDepositAndMonitorLogs(_caller, _depositAmount);

        /// @dev fulfill active request
        bytes memory response = abi.encode(_depositRequestResponse);
        _fulfillRequest(response, depositRequestId, depositCallbackGasLimit, depositEstimatedTotalCostJuels);

        return depositRequestId;
    }

    function _startWithdrawalAndFulfillRequest(
        address _caller,
        uint256 _withdrawalAmount,
        uint256 _withdrawalRequestResponse
    ) internal returns (bytes32) {
        /// @dev startWithdrawal
        (bytes32 withdrawalRequestId, uint32 withdrawalCallbackGasLimit, uint96 withdrawalEstimatedTotalCostJuels) =
            _startWithdrawalAndMonitorLogs(_caller, _withdrawalAmount);

        /// @dev fulfill active withdrawal request
        bytes memory withdrawResponse = abi.encode(_withdrawalRequestResponse);
        _fulfillRequest(
            withdrawResponse, withdrawalRequestId, withdrawalCallbackGasLimit, withdrawalEstimatedTotalCostJuels
        );

        return withdrawalRequestId;
    }
}
