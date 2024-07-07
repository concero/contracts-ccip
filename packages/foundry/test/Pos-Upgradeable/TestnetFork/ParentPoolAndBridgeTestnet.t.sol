// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {HelpersTestnet} from "./HelpersTestnet.sol";
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
import {IStorage} from "contracts/Interfaces/IStorage.sol";
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
    event ParentPool_MasterPoolCapUpdated(uint256 _newCap);
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
        emit ParentPool_MasterPoolCapUpdated(50*10**6);
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
        emit ParentPool_MasterPoolCapUpdated(1000*10**6);
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
    
    error Concero_ItsNotOrchestrator(address);
    function test_swapAndBridgeWithoutFunctions() public setters{
        helper();

        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(tUSDC);
        address to = address(op);
        uint deadline = block.timestamp + 1800;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(tUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(mockBase, path, to, deadline)
        });

        /////////////////////////// BRIDGE DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 350 *10**6,
            dstChainSelector: arbChainSelector,
            receiver: User
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);
        vm.expectRevert(abi.encodeWithSelector(Concero_ItsNotOrchestrator.selector, address(concero)));
        concero.startBridge(bridgeData, swapData);

        op.swapAndBridge(bridgeData, swapData, swapData);
        vm.stopPrank();

    }

    function test_userBridge() public setters {
        vm.selectFork(baseTestFork);

        uint256 lpBalance = IERC20(ccipBnM).balanceOf(LP);
        uint256 depositLowAmount = 10*10**6;

        //======= LP Deposits enough to go through, but revert on max Cap
        uint256 depositEnoughAmount = 100*10**6;

        //======= Increase the CAP
        vm.expectEmit();
        vm.prank(Tester);
        emit ParentPool_MasterPoolCapUpdated(1000*10**6);
        wMaster.setPoolCap(1000*10**6);

        vm.startPrank(LP);
        IERC20(ccipBnM).approve(address(wMaster), depositEnoughAmount);
        wMaster.depositLiquidity(depositEnoughAmount);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);
        vm.stopPrank();

        //====== Check Receiver balance
        assertEq(IERC20(ccipBnMArb).balanceOf(User), 0);
        assertEq(IERC20(ccipBnMArb).balanceOf(address(wChild)), depositEnoughAmount / 2);

        vm.selectFork(baseTestFork);

        //====== Mock the payload
        uint256 amountToSend = 10 *10**6;

        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.bnm,
            amount: amountToSend,
            dstChainSelector: arbChainSelector,
            receiver: User
        });

        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(tUSDC);
        address to = address(op);
        uint deadline = block.timestamp + 1800;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(tUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(mockBase, path, to, deadline)
        });

        vm.startPrank(User);
        IERC20(ccipBnM).approve(address(op), amountToSend);
        op.bridge(bridgeData, swapData);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);
        vm.stopPrank();

        //====== Check Receiver balance
        assertEq(IERC20(ccipBnMArb).balanceOf(User), 9831494); //Amount - fee = 9831494
        
        assertTrue(op.s_lastGasPrices(arbChainSelector) > 0);
        assertTrue(op.s_latestLinkUsdcRate() > 0);
        assertTrue(op.s_latestNativeUsdcRate() > 0);
        assertTrue(op.s_latestLinkNativeRate() > 0);
    }
}
