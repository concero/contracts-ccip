// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Helpers} from "./Helpers.sol";
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
import {Storage} from "contracts/Libraries/Storage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ParentPoolAndBridgeMainnet is Helpers {
    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    //This test only work with USDC Mainnet address on Storage::getToken function.
    error ParentPool_AmountBelowMinimum(uint256);
    error ParentPool_MaxCapReached(uint256);
    event ParentStorage_MasterPoolCapUpdated(uint256 _newCap);
    event ParentPool_SuccessfulDeposited(address, uint256 , address);
    event ParentPool_MessageSent(bytes32, uint64, address, address, uint256);
    // function test_LiquidityProvidersDepositAndOpenARequest() public setters {
    //     vm.selectFork(baseMainFork);

    //     swapUniV2LikeHelper();

    //     uint256 lpBalance = mUSDC.balanceOf(LP);
    //     uint256 depositLowAmount = 10*10**6;

    //     //======= LP Deposits Low Amount of USDC on the Main Pool to revert on Min Amount
    //     vm.startPrank(LP);
    //     mUSDC.approve(address(wMaster), depositLowAmount);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_AmountBelowMinimum.selector, 100*10**6));
    //     wMaster.depositLiquidity(depositLowAmount);
    //     vm.stopPrank();

    //     //======= Increase the CAP
    //     vm.expectEmit();
    //     vm.prank(Tester);
    //     emit ParentStorage_MasterPoolCapUpdated(50*10**6);
    //     wMaster.setPoolCap(50*10**6);

    //     //======= LP Deposits enough to go through, but revert on max Cap
    //     uint256 depositEnoughAmount = 100*10**6;

    //     vm.startPrank(LP);
    //     mUSDC.approve(address(wMaster), depositEnoughAmount);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_MaxCapReached.selector, 50*10**6));
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     vm.stopPrank();

    //     //======= Increase the CAP
    //     vm.expectEmit();
    //     vm.prank(Tester);
    //     emit ParentStorage_MasterPoolCapUpdated(1000*10**6);
    //     wMaster.setPoolCap(1000*10**6);

    //     //======= LP Deposits Successfully
    //     bytes32 ccipId = 0x454653b5e1c42416201bb8b5b62f9f2e27470cc5737130dec9fd6276eafb5304;

    //     vm.startPrank(LP);
    //     mUSDC.approve(address(wMaster), depositEnoughAmount);
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumMainFork);
    //     vm.stopPrank();

    //     //======= Check LP balance
    //     assertEq(mUSDC.balanceOf(LP), lpBalance - depositEnoughAmount);

    //     //======= We check the pool balance;
    //                 //Here, the LP Fees will be compounding directly for the LP address
    //     uint256 poolBalance = mUSDC.balanceOf(address(wMaster));
    //     assertEq(poolBalance, depositEnoughAmount/2);

    //     //======= Mock the Functions call
    //     vm.prank(address(wMaster));
    //     wMaster.updateUSDCAmountManually(LP, lp.totalSupply(), depositEnoughAmount, 0);

    //     uint256 lpTokenUserBalance = lp.balanceOf(LP);
    //     assertEq(lpTokenUserBalance, (depositEnoughAmount * 10**18) / 10**6);

    //     //======= Request Withdraw without any accrued fee
    //     vm.startPrank(LP);
    //     wMaster.startWithdrawal(lpTokenUserBalance);
    //     vm.stopPrank();

    //     //======= No operations are made. Advance time
    //     vm.warp(7 days);

    //     //======= Switch to Arbitrum
    //     vm.selectFork(arbitrumMainFork);

    //     //======= Calls ChildPool to send the money
    //     vm.prank(Messenger);
    //     wChild.ccipSendToPool(LP, depositEnoughAmount/2);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(baseMainFork);

    //     //======= Switch to Base
    //     vm.selectFork(baseMainFork);

    //     wMaster.updateUSDCAmountEarned(LP, lp.totalSupply(), lpTokenUserBalance, depositEnoughAmount/2);

    //     //======= Withdraw after the lock period and cross-chain transference
    //     vm.startPrank(LP);
    //     lp.approve(address(pool), lpTokenUserBalance);
    //     wMaster.completeWithdrawal();
    //     vm.stopPrank();

    //     // //======= Check LP balance
    //     assertEq(mUSDC.balanceOf(LP), lpBalance);
    // }
}
