// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Helpers} from "./Helpers.sol";
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
import {Storage} from "contracts/Libraries/Storage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConceroPoolAndBridge is Helpers {
    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    error ConceroPool_AmountBelowMinimum(uint256);
    error ConceroPool_MaxCapReached(uint256);
    event MasterStorage_MasterPoolCapUpdated(uint256 _newCap);
    event ConceroPool_SuccessfulDeposited(address, uint256 , address);
    function test_LiquidityProvidersDepositAndOpenARequest() public {
        vm.selectFork(baseMainFork);

        swapUniV2LikeHelper();

        uint256 lpBalance = mUSDC.balanceOf(LP);
        uint256 depositLowAmount = 10*10**6;

        //======= LP Deposits Low Amount of USDC on the Main Pool to revert on Min Amount
        vm.startPrank(LP);
        mUSDC.approve(address(wMaster), depositLowAmount);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_AmountBelowMinimum.selector, 100*10**6));
        wMaster.depositLiquidity(depositLowAmount);
        vm.stopPrank();

        //======= LP Deposits enough to go through, but revert on max Cap
        uint256 depositEnoughAmount = 100*10**6;

        vm.startPrank(LP);
        mUSDC.approve(address(wMaster), depositEnoughAmount);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_MaxCapReached.selector, 0));
        wMaster.depositLiquidity(depositEnoughAmount);
        vm.stopPrank();

        //======= Increase the CAP
        vm.expectEmit();
        vm.prank(Tester);
        emit MasterStorage_MasterPoolCapUpdated(1000*10**6);
        wMaster.setPoolCap(1000*10**6);

        //======= LP Deposits Successfully
        vm.startPrank(LP);
        mUSDC.approve(address(wMaster), depositEnoughAmount);
        vm.expectEmit();
        emit ConceroPool_SuccessfulDeposited(LP, depositEnoughAmount, address(mUSDC));
        wMaster.depositLiquidity(depositEnoughAmount);
        vm.stopPrank();

        //======= Check LP balance
        assertEq(mUSDC.balanceOf(LP), lpBalance - depositEnoughAmount);

        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        uint256 poolBalance = mUSDC.balanceOf(address(pool));
        assertEq(poolBalance, depositEnoughAmount);
        // uint256 lpTokenUserBalance = lpToken.balanceOf(LP);
        // assertEq(lpTokenUserBalance, (depositEnoughAmount * 10**18) / 10**6);

        // //======= Request Withdraw without any accrued fee
        // vm.startPrank(LP);
        // lpToken.approve(address(pool), lpTokenUserBalance);
        // // pool.withdrawLiquidityRequest(0);

        // //======= No operations are made. Advance time
        // vm.warp(8 days);

        // //======= Withdraw after the lock period
        // // pool.claimWithdraw();

        // //======= Check LP balance
        // assertEq(mUSDC.balanceOf(LP), lpBalance);
    }

    //Pool depositToken | availableToWithdraw | withdrawLiquidityRequest
    //Storage s_userBalances
    event WillRevertAfterThis();
    function test_LiquidityProvidersDepositAndWithdraws() public {
        vm.selectFork(baseMainFork);

        swapUniV2LikeHelper();

        uint256 lpBalance = mUSDC.balanceOf(LP);

        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(LP);
        mUSDC.approve(address(pool), lpBalance);
        emit WillRevertAfterThis();
        pool.depositLiquidity(lpBalance);
        vm.stopPrank();

        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        uint256 poolBalance = mUSDC.balanceOf(address(pool));
        assertEq(poolBalance, lpBalance);

        //======= Request Withdraw bigger than THRESHOLD
        vm.startPrank(LP);
        // pool.withdrawLiquidity(0);
    }

    function test_ccipSendToPool() public {
        vm.selectFork(arbitrumMainFork);

        arbSwapUniV2Link();

        //======= Transfer the link to the pool
        vm.startPrank(LP);
        IERC20(linkArb).transfer(address(proxyDst), 10 ether);
        IERC20(linkArb).transfer(address(child), 10 ether);
        vm.stopPrank();

        uint256 lpBalance = aUSDC.balanceOf(LP);

        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(LP);
        aUSDC.approve(address(child), lpBalance);
        // child.depositLiquidity(lpBalance);
        vm.stopPrank();

        vm.prank(Messenger);
        child.ccipSendToPool(baseChainSelector, LP, address(aUSDC), (lpBalance/2));
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseMainFork);
    }
}
