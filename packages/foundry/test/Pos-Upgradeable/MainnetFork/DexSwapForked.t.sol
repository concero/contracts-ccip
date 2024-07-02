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
    ///////////////////////////////// SWAPPING MODULE /////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////
    error DexSwap_CallableOnlyByOwner(address, address);
    event DexSwap_RemovingDust(address, uint256);
    error DexSwap_EmptyDexData();
    error Orchestrator_UnableToCompleteDelegateCall(bytes);
    error Orchestrator_InvalidSwapData();
    function test_swapUniV2LikeMock() public {
        helper();

        uint amountIn = 1*10**16;
        uint amountOutMin = 300*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = User;
        uint deadline = block.timestamp + 1800;

        //=================================== Successful Leg =========================================\\

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        //==== Initiate transaction
        op.swap(swapData, to);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), amountIn / 1000);
        assertTrue(mUSDC.balanceOf(User) >= amountOutMin);
        vm.stopPrank();
        
        //=================================== Revert Leg =========================================\\

        ///==== Invalid Path

        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(mUSDC),
                            fromAmount: 1*10**6,
                            toToken: address(wEth),
                            toAmount: 1*10**8,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        mUSDC.approve(address(op), 1*10**6);

        bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);

        //==== Initiate transaction
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
        op.swap(swapData, to);
        vm.stopPrank();

        ///==== Invalid Router
        
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(User, path, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        //==== Initiate transaction
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, to);
        vm.stopPrank();

        ///==== Invalid dexData
        
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: ""
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        //==== Initiate transaction
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, to);
        vm.stopPrank();

        //=================================== Dust Withdraw =========================================\\
        //===== Mock some dust stuck on the protocol
        vm.prank(User);
        mUSDC.transfer(address(dex), 300 *10**5);
        assertEq(mUSDC.balanceOf(address(dex)), 300 *10**5);

        //==== Arbitrary address tries to withdraw it and revert
        vm.expectRevert(abi.encodeWithSelector(DexSwap_CallableOnlyByOwner.selector, address(this), defaultSender));
        dex.dustRemoval(address(mUSDC), 300 *10**5);

        vm.prank(defaultSender);
        vm.expectEmit();
        emit DexSwap_RemovingDust(defaultSender, 300 *10**5);
        dex.dustRemoval(address(mUSDC), 300 *10**5);
    }

    function test_swapUniV2LikeFoTMock() public {
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
                            dexType: IDexSwap.DexType.UniswapV2FoT,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);

        //==== Initiate transaction
        op.swap(swapData, to);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOutMin);

        ////================================= Revert =============================\\\\\
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2FoT,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: ""
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, to);

        ////================================== REVERT ====================================\\\\
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2FoT,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(User, path, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, to);

        ////================================== REVERT ====================================\\\\
        path[0] = address(mUSDC);
        path[1] = address(mUSDC);

        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2FoT,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);
        bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
        op.swap(swapData, to);
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
                            dexData: abi.encode(sushiV3, 500, block.timestamp + 1800, 0)
                        });

        vm.startPrank(User);
        wEth.approve(address(op), 1 ether);

        op.swap(swapData, User);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User))> USDC_INITIAL_BALANCE + amountOut);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.SushiV3Single,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: 1*10**5,
                            toAmountMin: amountOut,
                            dexData: abi.encode(User, 500, block.timestamp + 1800, 0)
                        });

        vm.startPrank(User);
        wEth.approve(address(op), 1 ether);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);
        vm.stopPrank();

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.SushiV3Single,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: 1*10**5,
                            toAmountMin: amountOut,
                            dexData: ""
                        });

        vm.startPrank(User);
        wEth.approve(address(op), 1 ether);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);
        vm.stopPrank();
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
            dexData: abi.encode(uniswapV3, 500, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData, User);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

        //=================================== Revert Leg =========================================\\

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, 500, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);

        //=================================== Revert Leg =========================================\\

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);
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
            dexData: abi.encode(sushiV3, path, block.timestamp + 300)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

        op.swap(swapData, User);

        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.SushiV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(wEth),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, path, block.timestamp + 300)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.SushiV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(wEth),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);
    }

    error DexSwap_InvalidPath();
    error DexSwap_RouterNotAllowed();
    function test_revertSwapSushiV3MultiMockInvalidPath() public {
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
            dexData: abi.encode(sushiV3, path, block.timestamp + 300)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData, User);

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
            dexData: abi.encode(uniswapV3, path, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        op.swap(swapData, User);

        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, path, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);
    }

    function test_revertSwapUniV3MultiMockInvalidPath() public {
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
            dexData: abi.encode(uniswapV3, path)
        });


        vm.startPrank(User);

        wEth.approve(address(op), amountIn);
        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData, User);
        
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
            dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        op.swap(swapData, User);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

        ///============================= Invalid Path Revert
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.Aerodrome,
            fromToken: address(mUSDC),
            fromAmount: 350*10**5,
            toToken: address(wEth),
            toAmount: 1*10**8,
            toAmountMin: 1*10**8,
            dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        mUSDC.approve(address(op), 350*10**5);
        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData, User);

        ///============================= Empty Dex Data Revert

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.Aerodrome,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);

        ///============================= Empty Dex Data Revert

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.Aerodrome,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);
    }

    function test_swapDromeFoTMock() public {
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
            dexType: IDexSwap.DexType.AerodromeFoT,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData, User);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

        ///============================= Invalid Path Revert
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.Aerodrome,
            fromToken: address(mUSDC),
            fromAmount: 350*10**5,
            toToken: address(wEth),
            toAmount: 1*10**8,
            toAmountMin: 1*10**8,
            dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        mUSDC.approve(address(op), 350*10**5);
        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData, User);

        ///============================= Empty Dex Data
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.AerodromeFoT,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);

        ///============================= Router Not allowed Revert
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.AerodromeFoT,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);

        ///============================= Router Not allowed Revert

        IRouter.Route memory routesTwo = IRouter.Route({
            from: address(mUSDC),
            to: address(mUSDC),
            stable: false,
            factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
        });

        route[0] = routesTwo;

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.AerodromeFoT,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
        op.swap(swapData, User);
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
        vm.deal(User, 1*10**17);
        assertEq(User.balance, 1*10**17);

        //===== Mock the payload to send on the function
        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV2, path, deadline)
        });

        //===== Start transaction calling the function and passing the payload
        vm.startPrank(User);
        op.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        assertEq(User.balance, 0);
        assertEq(wEth.balanceOf(address(op)), 0);
        assertEq(address(op).balance, 1*10**17 / 1000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

        uint256 userBalance = User.balance;

        vm.deal(address(dex), 1*10**18);

        assertEq(1*10**18, address(dex).balance);

        vm.prank(defaultSender);
        dex.dustEtherRemoval(User);

        assertEq(User.balance, userBalance  + 1*10**18);

        ////================================ Empty Dex Data =================================\\\\\\
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        ////================================ Router not allowed =================================\\\\\\
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, path, deadline)
        });

        vm.startPrank(User);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        ////================================ Invalid Path =================================\\\\\\
        
        //===== Mock the data for payload to send to the function
        amountOut = 350*10*6;
        path[0] = address(0);
        path[1] = address(mUSDC);
        to = address(User);
        deadline = block.timestamp + 1800;

        //===== Gives User some ether and checks the balance
        vm.deal(User, 1*10**17);
        assertEq(User.balance, 1*10**17);

        //===== Mock the payload to send on the function
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV2, path, deadline)
        });

        //===== Start transaction calling the function and passing the payload
        vm.startPrank(User);
        bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
        op.swap{value: amountIn}(swapData, User);
        vm.stopPrank();
    }

    function test_customMultiHopFunctionalitySuccess() public {
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
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
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        //==== Initiate transaction

        /////=============== TEST CHAINED TX =====================\\\\\        
        
        amountIn = 350*10**5;
        amountOutMin = 1*10**16;
        path = new address[](2);
        path[0] = address(mUSDC);
        path[1] = address(wEth);

        swapData[1] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(mUSDC),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        //==== Initiate transaction
        op.swap(swapData, User);
    }

    error DexSwap_SwapDataNotChained(address, address);
    function test_customMultiHopFunctionalityRevert() public {
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
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
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        /////=============== TEST CHAINED TX =====================\\\\\
        swapData[1] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        //==== Initiate transaction
        bytes memory notChained = abi.encodeWithSelector(DexSwap_SwapDataNotChained.selector, address(mUSDC), address(wEth));

        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, notChained));
        op.swap(swapData, User);
    }

    error DexSwap_ItsNotOrchestrator(address);
    function test_revertConceroEntry() public {
        
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        vm.expectRevert(abi.encodeWithSelector(DexSwap_ItsNotOrchestrator.selector, address(dex)));
        dex.conceroEntry(swapData, 0, User);
        
        IDexSwap.SwapData[] memory emptyData = new IDexSwap.SwapData[](0);

        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swap(emptyData, User);
        
        IDexSwap.SwapData[] memory fullData = new IDexSwap.SwapData[](6);
        fullData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[1] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[2] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[3] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[4] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[5] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swap(fullData, User);
    }
}
