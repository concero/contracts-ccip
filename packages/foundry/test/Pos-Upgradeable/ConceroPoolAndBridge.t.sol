// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Helpers} from "./Helpers.sol";
import {IConcero, IDexSwap} from "../../src/Interfaces/IConcero.sol";
import {Storage} from "../../src/Libraries/Storage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ConceroPoolAndBridge is Helpers {
    uint256 constant WITHDRAW_THRESHOLD = 10;

    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    //Pool depositToken | availableToWithdraw | withdrawLiquidityRequest
    //Storage s_userBalances
    function test_LiquidityProvidersDepositAndOpenARequest() public {
        vm.selectFork(baseMainFork);

        swapUniV2LikeHelper();

        uint256 lpBalance = mUSDC.balanceOf(LP);

        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(LP);
        mUSDC.approve(address(pool), lpBalance);
        pool.depositToken(address(mUSDC), lpBalance);
        vm.stopPrank();
        
        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        uint256 poolBalance = mUSDC.balanceOf(address(pool));
        assertEq(poolBalance, lpBalance);

        //======= Check the provider balance
        assertEq(pool.s_userBalances(address(mUSDC), LP), lpBalance);

        //======= Lets check how much is available to withdraw
        uint256 amountToWithdraw = pool.availableToWithdraw(address(mUSDC));
        assertEq(amountToWithdraw, ((lpBalance * WITHDRAW_THRESHOLD)/100));

        //======= Request Withdraw bigger than THRESHOLD
        vm.startPrank(LP);
        pool.withdrawLiquidityRequest(address(mUSDC), amountToWithdraw + 1);

        //======= Check created request
        Storage.WithdrawRequests memory request = pool.getRequestInfo(address(mUSDC));
        assertEq(request.condition, (poolBalance - (poolBalance * WITHDRAW_THRESHOLD)/100) + amountToWithdraw +1);
        assertEq(request.amount, amountToWithdraw + 1);
        assertEq(request.isActiv, true);

        //======= Lets check how much is available to withdraw
        uint256 amountToWithdrawAfterRequest = pool.availableToWithdraw(address(mUSDC));
        assertEq(amountToWithdrawAfterRequest, 0);
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
        pool.depositToken(address(mUSDC), lpBalance);
        vm.stopPrank();
        
        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        uint256 poolBalance = mUSDC.balanceOf(address(pool));
        assertEq(poolBalance, lpBalance);

        //======= Check the provider balance
        assertEq(pool.s_userBalances(address(mUSDC), LP), lpBalance);

        //======= Lets check how much is available to withdraw
        uint256 amountToWithdraw = pool.availableToWithdraw(address(mUSDC));
        assertEq(amountToWithdraw, ((lpBalance * WITHDRAW_THRESHOLD)/100));

        //======= Request Withdraw bigger than THRESHOLD
        vm.startPrank(LP);
        pool.withdrawLiquidityRequest(address(mUSDC), amountToWithdraw - 1);

        //======= Check Pool balance
        assertEq(mUSDC.balanceOf(address(pool)), (lpBalance - (amountToWithdraw - 1)));
        assertEq(pool.s_userBalances(address(mUSDC), LP), (lpBalance - (amountToWithdraw - 1)));

        //======= Lets check how much is available to withdraw
        uint256 amountToWithdrawAfterRequest = pool.availableToWithdraw(address(mUSDC));
        assertEq(amountToWithdrawAfterRequest, (((lpBalance - (amountToWithdraw - 1))* WITHDRAW_THRESHOLD)/100));
    }
    
    function test_ccipSendToPool() public {
        vm.selectFork(arbitrumMainFork);

        arbSwapUniV2Link();

        uint256 lpBalance = aUSDC.balanceOf(LP);

        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(LP);
        aUSDC.approve(address(poolDst), lpBalance);
        poolDst.depositToken(address(aUSDC), lpBalance);
        vm.stopPrank();

        //======= Transfer the link to the pool
        vm.startPrank(LP);
        IERC20(linkArb).transfer(address(proxyDst), 10 ether);
        IERC20(linkArb).transfer(address(poolDst), 10 ether);
        vm.stopPrank();

        vm.prank(Messenger);
        poolDst.ccipSendToPool(baseChainSelector, address(aUSDC), (lpBalance/2));
        ccipLocalSimulatorFork.switchChainAndRouteMessage(baseMainFork);
    }


}