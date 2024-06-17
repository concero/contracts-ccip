// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DexSwapForked} from "./DexSwapForked.t.sol";

//Protocol Interfaces
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";

contract Helpers is DexSwapForked {

    event FirstLegDone();
    function swapUniV2LikeHelper() public {
        vm.deal(User, INITIAL_BALANCE);
        vm.deal(LP, LP_INITIAL_BALANCE);

        vm.startPrank(User);
        wEth.deposit{value: INITIAL_BALANCE}();
        vm.stopPrank();

        vm.startPrank(LP);
        wEth.deposit{value: LP_INITIAL_BALANCE}();
        vm.stopPrank();

        assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
        assertEq(wEth.balanceOf(LP), LP_INITIAL_BALANCE);

        uint amountIn = LP_INITIAL_BALANCE;
        uint amountOutMin = 4 *10**6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = LP;
        uint deadline = block.timestamp + 1800;

        vm.startPrank(LP);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(uniswapV2, path, to, deadline)
                        });

        // ==== Approve Transfer
        wEth.approve(address(op), amountIn);

        //==== Initiate transaction
        op.swap(swapData);
        vm.stopPrank();

        emit FirstLegDone();
    }

    function arbSwapUniV2Link() public {

        vm.deal(User, INITIAL_BALANCE);
        vm.deal(LP, LP_INITIAL_BALANCE);

        vm.startPrank(User);
        arbWEth.deposit{value: INITIAL_BALANCE}();
        vm.stopPrank();

        vm.startPrank(LP);
        arbWEth.deposit{value: LP_INITIAL_BALANCE}();
        vm.stopPrank();

        uint amountIn = LP_INITIAL_BALANCE / 2;
        uint amountOutMin = 4 *10**6;
        address[] memory path = new address[](2);
        path[0] = address(arbWEth);
        path[1] = address(aUSDC);
        address to = LP;
        uint deadline = block.timestamp + 1800;

        vm.startPrank(LP);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(arbWEth),
                            fromAmount: amountIn,
                            toToken: address(aUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(uniswapV2Arb, path, to, deadline)
                        });

        // ==== Approve Transfer
        arbWEth.approve(address(opDst), amountIn);

        //==== Initiate transaction
        opDst.swap(swapData);
        vm.stopPrank();

        emit FirstLegDone();

        uint secondAmountIn = LP_INITIAL_BALANCE / 2;
        uint secondAmountOutMin = 200 *10**18;
        address[] memory secondPath = new address[](2);
        secondPath[0] = address(arbWEth);
        secondPath[1] = address(linkArb);
        address secondTo = LP;
        uint secondDeadline = block.timestamp + 1800;

        IDexSwap.SwapData[] memory secondSwapData = new IDexSwap.SwapData[](1);
        secondSwapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(arbWEth),
                            fromAmount: secondAmountIn,
                            toToken: address(linkArb),
                            toAmount: secondAmountOutMin,
                            toAmountMin: secondAmountOutMin,
                            dexData: abi.encode(sushiV2Arb, secondPath, secondTo, secondDeadline)
                        });

        vm.startPrank(LP);
        arbWEth.approve(address(opDst), secondAmountIn);

        //==== Initiate transaction
        opDst.swap(secondSwapData);

        assertEq(arbWEth.balanceOf(address(LP)), 0);
        assertTrue(IERC20(linkArb).balanceOf(address(LP)) > amountOutMin);
    }
}
