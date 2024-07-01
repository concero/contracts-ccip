// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {HelpersTestnet} from "./HelpersTestnet.sol";
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
import {Storage} from "contracts/Libraries/Storage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ParentPoolAndBridgeTestnet is HelpersTestnet {
    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    error ParentPool_AmountBelowMinimum(uint256);
    error ParentPool_MaxCapReached(uint256);
    error ParentPool_AmountNotAvailableYet(uint256);
    error ParentPool_InsufficientBalance();
    error ParentPool_ActiveRequestNotFulfilledYet();
    error ParentPool_CallerIsNotTheProxy(address);
    event ParentStorage_MasterPoolCapUpdated(uint256 _newCap);
    event ParentPool_SuccessfulDeposited(address, uint256 , address);
    event ParentPool_MessageSent(bytes32, uint64, address, address, uint256);
    event ParentPool_WithdrawRequest(address,address,uint256);
    event ParentPool_Withdrawn(address,address,uint256);
    function test_LiquidityProvidersDepositAndOpenARequest() public setters {
        vm.selectFork(baseTestFork);

        uint256 lpBalance = IERC20(ccipBnM).balanceOf(LP);
        uint256 depositLowAmount = 10*10**6;

        //======= LP Deposits Low Amount of USDC on the Main Pool to revert on Min Amount
        vm.startPrank(LP);
        IERC20(ccipBnM).approve(address(wMaster), depositLowAmount);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_AmountBelowMinimum.selector, 100*10**6));
        wMaster.depositLiquidity(depositLowAmount);
        vm.stopPrank();

        //======= Increase the CAP
        vm.expectEmit();
        vm.prank(Tester);
        emit ParentStorage_MasterPoolCapUpdated(50*10**6);
        wMaster.setPoolCap(50*10**6);

        //======= LP Deposits enough to go through, but revert on max Cap
        uint256 depositEnoughAmount = 100*10**6;

        vm.startPrank(LP);
        IERC20(ccipBnM).approve(address(wMaster), depositEnoughAmount);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_MaxCapReached.selector, 50*10**6));
        wMaster.depositLiquidity(depositEnoughAmount);
        vm.stopPrank();

        //======= Increase the CAP
        vm.expectEmit();
        vm.prank(Tester);
        emit ParentStorage_MasterPoolCapUpdated(1000*10**6);
        wMaster.setPoolCap(1000*10**6);

        vm.startPrank(LP);
        IERC20(ccipBnM).approve(address(wMaster), depositEnoughAmount);
        wMaster.depositLiquidity(depositEnoughAmount);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);
        vm.stopPrank();

        //======= Switch to Base
        vm.selectFork(baseTestFork);

        //======= Check LP balance
        assertEq(IERC20(ccipBnM).balanceOf(LP), lpBalance - depositEnoughAmount);

        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        uint256 poolBalance = IERC20(ccipBnM).balanceOf(address(wMaster));
        assertEq(poolBalance, depositEnoughAmount/2);

        //======= Mock the Functions call
        vm.prank(address(wMaster));
        wMaster.updateUSDCAmountManually(LP, lp.totalSupply(), depositEnoughAmount, 0);

        uint256 lpTokenUserBalance = lp.balanceOf(LP);
        assertEq(lpTokenUserBalance, (depositEnoughAmount * 10**18) / 10**6);

        //======= Revert on amount bigger than balance
        vm.startPrank(LP);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_InsufficientBalance.selector));
        wMaster.startWithdrawal(lpTokenUserBalance + 10);
        vm.stopPrank();

        //======= Request Withdraw without any accrued fee
        vm.startPrank(LP);
        vm.expectEmit();
        emit ParentPool_WithdrawRequest(LP, ccipBnM, block.timestamp + 597_600);
        wMaster.startWithdrawal(lpTokenUserBalance);
        vm.stopPrank();

        wMaster.updateUSDCAmountEarned(LP, lp.totalSupply(), lpTokenUserBalance, depositEnoughAmount/2);

        //======= Revert on amount bigger than balance
        vm.startPrank(LP);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_ActiveRequestNotFulfilledYet.selector));
        wMaster.startWithdrawal(lpTokenUserBalance);
        vm.stopPrank();

        //======= No operations are made. Advance time
        vm.warp(7 days);

        //======= Revert Because money not arrived yet
        vm.startPrank(LP);
        lp.approve(address(wMaster), lpTokenUserBalance);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_AmountNotAvailableYet.selector, 50*10**6));
        wMaster.completeWithdrawal();
        vm.stopPrank();

        //======= Switch to Arbitrum
        vm.selectFork(arbitrumTestFork);

        //======= Calls ChildPool to send the money
        vm.prank(Messenger);
        wChild.ccipSendToPool(LP, depositEnoughAmount/2);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseTestFork);

        //======= Revert because balance was used.
        vm.prank(address(wMaster));
        IERC20(ccipBnM).transfer(User, 10*10**6);

        vm.startPrank(LP);
        lp.approve(address(wMaster), lpTokenUserBalance);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_InsufficientBalance.selector));
        wMaster.completeWithdrawal();
        vm.stopPrank();

        vm.prank(address(User));
        IERC20(ccipBnM).transfer(address(wMaster), 10*10**6);

        vm.startPrank(LP);
        lp.approve(address(wMaster), lpTokenUserBalance);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_CallerIsNotTheProxy.selector, address(pool)));
        pool.completeWithdrawal();
        vm.stopPrank();

        //======= Withdraw after the lock period and cross-chain transference
        vm.startPrank(LP);
        lp.approve(address(wMaster), lpTokenUserBalance);
        wMaster.completeWithdrawal();
        vm.stopPrank();

        // //======= Check LP balance
        assertEq(IERC20(ccipBnM).balanceOf(LP), lpBalance);
    }
}
