// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {ProtocolTest} from "./Protocol.t.sol";

//Protocol Interfaces
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";

//DEXes routers
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {ISwapRouter02, IV3SwapRouter} from "contracts/Interfaces/ISwapRouter02.sol";

contract DexSwapForked is ProtocolTest {

    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// SWAPING MODULE /////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////
    function test_swapUniV2LikeMock() public {
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = User;
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(concero), amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, to, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);

        //==== Initiate transaction
        op.swap(swapData);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOutMin);
    }

    function test_swapSushiV3SingleMock() public {
        helper();
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;
        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.SushiV3Single,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: 1*10**5,
                            toAmountMin: amountOut,
                            dexData: abi.encode(sushiV3, 500, address(User), block.timestamp + 1800, 0)
                        });

        vm.startPrank(User);
        wEth.approve(address(op), 1 ether);

        op.swap(swapData);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User))> USDC_INITIAL_BALANCE + amountOut);
    }

    function test_swapUniV3SingleMock() public {
        helper();
        assertEq(wEth.balanceOf(address(dex)), 0);

        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, 500, User, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    function test_swapSushiV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 1*10**16;

        bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.SushiV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(wEth),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(sushiV3, path, address(User), block.timestamp + 300)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

        op.swap(swapData);

        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);
    }

    error DexSwap_InvalidPath();
    function test_revertSwapSushiV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 1*10**16;

        bytes memory path = abi.encodePacked(mUSDC, poolFee, wEth, poolFee, mUSDC);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.SushiV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(wEth),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(sushiV3, path, address(User), block.timestamp + 300)
        });

        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData);

        vm.stopPrank();
    }

    function test_swapUniV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path, address(User), block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData);

        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);
    }

    function test_revertSwapUniV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 350*10*6;
        uint256 amountOut = 1*10**17;

        bytes memory path = abi.encodePacked(mUSDC, poolFee, wEth, poolFee, mUSDC);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path, address(User))
        });

        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);

        vm.startPrank(User);

        wEth.approve(address(op), amountIn);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData);
        
        vm.stopPrank();
    }

    function test_swapDromeMock() public {
        helper();

        assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        IRouter.Route[] memory route = new IRouter.Route[](1);

        IRouter.Route memory routes = IRouter.Route({
            from: address(wEth),
            to: address(mUSDC),
            stable: false,
            factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
        });

        route[0] = routes;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.Aerodrome,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(aerodromeRouter, route, User, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    function test_swapEtherOnUniV2LikeMock() public {
        helper();

        //===== Mock the value.
                //In this case, the value is passed as a param through the function
                //Also is transferred in the call
        uint256 amountIn = 1*10**17;

        //===== Mock the data for payload to send to the function
        uint256 amountOut = 350*10*6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = address(User);
        uint deadline = block.timestamp + 1800;

        //===== Gives User some ether and checks the balance
        vm.deal(User, INITIAL_BALANCE);
        assertEq(User.balance, INITIAL_BALANCE);

        //===== Mock the payload to send on the function
        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV2, path, to, deadline)
        });

        //===== Start transaction calling the function and passing the payload
        vm.startPrank(User);
        op.swap{value: amountIn}(swapData);
        vm.stopPrank();

        assertEq(User.balance, INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 0);
        assertEq(address(op).balance, 0);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    function test_customMultiHopFunctionalitySuccess() public {
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = address(op);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](2);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, to, deadline)
        });

        //==== Initiate transaction

        /////=============== TEST CHAINED TX =====================\\\\\        
        
        amountIn = 350*10**5;
        amountOutMin = 1*10**16;
        path = new address[](2);
        path[0] = address(mUSDC);
        path[1] = address(wEth);
        to = address(User);

        swapData[1] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(mUSDC),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, to, deadline)
        });

        //==== Initiate transaction
        op.swap(swapData);
    }

    error DexSwap_SwapDataNotChained(address, address);
    error Orchestrator_UnableToCompleteDelegateCall(bytes);
    function test_customMultiHopFunctionalityRevert() public {
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = address(op);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](2);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, to, deadline)
        });

        to = User;

        /////=============== TEST CHAINED TX =====================\\\\\
        swapData[1] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, to, deadline)
        });

        //==== Initiate transaction
        bytes memory notChained = abi.encodeWithSelector(DexSwap_SwapDataNotChained.selector, address(mUSDC), address(wEth));

        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, notChained));
        op.swap(swapData);
    }
}
