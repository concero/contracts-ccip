// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Helpers} from "./Helpers.sol";
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
import {Storage} from "contracts/Libraries/Storage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConceroPoolAndBridge is Helpers {
    uint256 constant WITHDRAW_THRESHOLD = 10;

    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    //Pool depositLiquidity | availableToWithdraw | withdrawLiquidityRequest
    //Storage s_userBalances
    function test_LiquidityProvidersDepositAndOpenARequest() public {
        vm.selectFork(baseMainFork);

        swapUniV2LikeHelper();

        //======= GET Lanca address.
        IERC20 lanca = pool.lanca();

        uint256 lpBalance = mUSDC.balanceOf(LP);

        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(LP);
        mUSDC.approve(address(pool), lpBalance);
        pool.depositLiquidity(lpBalance);
        vm.stopPrank();

        //======= Check LP balance
        assertEq(mUSDC.balanceOf(LP), 0);

        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        uint256 poolBalance = mUSDC.balanceOf(address(pool));
        assertEq(poolBalance, lpBalance);
        uint256 lancaUserBalance = lanca.balanceOf(LP);
        assertEq(lancaUserBalance, (lpBalance * 10**18) / 10**6);

        //======= Request Withdraw without any accrued fee
        vm.startPrank(LP);
        lanca.approve(address(pool), lancaUserBalance);
        pool.withdrawLiquidityRequest(0);

        //======= No operations are made. Advance time
        vm.warp(8 days);

        //======= Withdraw after the lock period
        pool.claimWithdraw();

        //======= Check LP balance
        assertEq(mUSDC.balanceOf(LP), lpBalance);
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
        IERC20(linkArb).transfer(address(poolDst), 10 ether);
        vm.stopPrank();

        uint256 lpBalance = aUSDC.balanceOf(LP);

        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(LP);
        aUSDC.approve(address(poolDst), lpBalance);
        poolDst.depositLiquidity(lpBalance);
        vm.stopPrank();

        vm.prank(Messenger);
        poolDst.ccipSendToPool(baseChainSelector, address(aUSDC), (lpBalance/2));
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseMainFork);
    }
}
