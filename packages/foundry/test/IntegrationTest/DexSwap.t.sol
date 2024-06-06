//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.19;
//
//import {Test, console} from "forge-std/Test.sol";
//import {DexSwapScript} from "../../script/DexSwapScript.s.sol";
//import {DexSwap} from "contracts/DexSwap.sol";
//import {IDexSwap} from "contracts/IDexSwap.sol";
//
//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
//import {DEXMock} from "../Mocks/DEXMock.sol";
//import {DEXMock2} from "../Mocks/DEXMock2.sol";
//import {USDC} from "../Mocks/USDC.sol";
//
//import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
//import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
//import {IRouter} from "@velodrome/contracts/interfaces/IRouter.sol";
//import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
//import {ISwapRouter02, IV3SwapRouter} from "../../src/Interfaces/ISwapRouter02.sol";
//
//contract DexSwapTest is Test {
//    DexSwapScript public deploy;
//    DexSwap public dex;
//
//    ERC20Mock wEth;
//    USDC public mUSDC;
//    ERC20Mock AERO;
//    DEXMock dexMock;
//
//    address Orchestrator = makeAddr("Orchestrator");
//    address Barba = makeAddr("Barba");
//    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
//
//    uint256 private constant PT_INITIAL_BALANCE = 100 ether;
//    uint256 private constant USDC_INITIAL_BALANCE = 100 * 10**6;
//    uint256 private constant ORCH_BALANCE = 10 ether;
//    uint256 private constant ORCH_USDC_BALANCE = 10 * 10**6;
//
//    function setUp() public {
//
//        wEth = new ERC20Mock("Test Wrapped Ether", "wEth", Barba, PT_INITIAL_BALANCE);
//        AERO = new ERC20Mock("Test AERO", "AERO", Barba, PT_INITIAL_BALANCE);
//        mUSDC = new USDC("USDC", "mUSDC", Barba, USDC_INITIAL_BALANCE);
//
//        dexMock = new DEXMock(address(mUSDC));
//
//        wEth.mint(Orchestrator, ORCH_BALANCE);
//        AERO.mint(Orchestrator, ORCH_BALANCE);
//        mUSDC.mint(Orchestrator, ORCH_USDC_BALANCE);
//
//        deploy = new DexSwapScript();
//        dex = deploy.run();
//
//        vm.prank(defaultSender);
//        dex.transferOwnership(Barba);
//
//        vm.startPrank(Barba);
//        dex.manageOrchestratorContract(Orchestrator);
//        dex.manageRouterAddress(address(dexMock), 1);
//        vm.stopPrank();
//    }
//
//    function helper() public {
//        vm.startPrank(Barba);
//        wEth.approve(address(dexMock), PT_INITIAL_BALANCE);
//        AERO.approve(address(dexMock), PT_INITIAL_BALANCE);
//        mUSDC.approve(address(dexMock), USDC_INITIAL_BALANCE);
//        dexMock.depositToken(address(wEth), PT_INITIAL_BALANCE);
//        dexMock.depositToken(address(AERO), PT_INITIAL_BALANCE);
//        dexMock.depositToken(address(mUSDC), USDC_INITIAL_BALANCE);
//        vm.stopPrank();
//        assertEq(wEth.balanceOf(address(dexMock)), PT_INITIAL_BALANCE);
//        assertEq(AERO.balanceOf(address(dexMock)), PT_INITIAL_BALANCE);
//        assertEq(mUSDC.balanceOf(address(dexMock)), USDC_INITIAL_BALANCE);
//    }
//
//    function test_swapUniV2LikeMock() public {
//        helper();
//
//        uint amountIn = 1*10**17;
//        uint amountOutMin = 1*10**5;
//        address[] memory path = new address[](2);
//        path[0] = address(wEth);
//        path[1] = address(mUSDC);
//        address to = address(Orchestrator);
//        uint deadline = block.timestamp + 1800;
//
//        vm.startPrank(Orchestrator);
//        wEth.approve(address(dex), amountIn);
//
//        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//        swapData[0] = IDexSwap.SwapData({
//                            dexType: IDexSwap.DexType.UniswapV2,
//                            fromToken: address(wEth),
//                            fromAmount: amountIn,
//                            toToken: address(mUSDC),
//                            toAmount: amountOutMin,
//                            toAmountMin: amountOutMin,
//                            dexData: abi.encode(dexMock, path, to, deadline)
//                        });
//
//        dex.conceroEntry(swapData, 0);
//
//        assertEq(wEth.balanceOf(address(Orchestrator)), ORCH_BALANCE - amountIn);
//        assertEq(wEth.balanceOf(address(dex)), 0);
//        assertEq(mUSDC.balanceOf(address(Orchestrator)), ORCH_USDC_BALANCE + amountOutMin);
//    }
//
//    ///_swapSushiV3Single///
//    // function test_swapSushiV3SingleMock() public {
//    //     helper();
//
//    //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//    //     swapData[0] = IDexSwap.SwapData({
//    //                         dexType: IDexSwap.DexType.SushiV3Single,
//    //                         fromToken: address(wEth),
//    //                         fromAmount: 1*10**17,
//    //                         toToken: address(mUSDC),
//    //                         toAmount: 1*10**5,
//    //                         toAmountMin: 1*10**5,
//    //                         dexData: abi.encode(dexMock, 500, address(Orchestrator), block.timestamp + 1800, 0)
//    //                     });
//
//    //     vm.startPrank(Orchestrator);
//    //     wEth.approve(address(dex), 1 ether);
//
//    //     dex.conceroEntry(swapData, 0);
//
//    //     assertEq(wEth.balanceOf(address(Orchestrator)), 9.9 ether);
//    //     assertEq(wEth.balanceOf(address(dex)), 0);
//    //     assertEq(mUSDC.balanceOf(address(Orchestrator)), ORCH_USDC_BALANCE + 1*10**5);
//    // }
//
//    event Log(string message);
//    event LogBytes(string message, bytes data);
//    function test_swapUniV3SingleMock() public {
//        helper();
//        assertEq(wEth.balanceOf(address(dex)), 0);
//
//        uint256 amountToDeposit = 1*10**17;
//        uint256 amountToReceive = 1*10**5;
//
//        IDexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//
//        swapData[0] = IDexSwap.SwapData({
//            dexType: IDexSwap.DexType.UniswapV3Single,
//            fromToken: address(wEth),
//            fromAmount: amountToDeposit,
//            toToken: address(mUSDC),
//            toAmount: amountToReceive,
//            toAmountMin: amountToReceive,
//            dexData: abi.encode(address(dexMock), 500, Orchestrator, 0)
//        });
//
//        vm.startPrank(Orchestrator);
//        wEth.approve(address(dex), amountToDeposit);
//
//        dex.conceroEntry(swapData, 0);
//
//        assertEq(wEth.balanceOf(address(Orchestrator)), ORCH_BALANCE - amountToDeposit);
//        assertEq(mUSDC.balanceOf(address(Orchestrator)), ORCH_USDC_BALANCE + amountToReceive);
//        assertEq(wEth.balanceOf(address(dex)), 0);
//        assertEq(wEth.balanceOf(address(dexMock)), PT_INITIAL_BALANCE + amountToDeposit);
//        assertEq(mUSDC.balanceOf(address(dexMock)), USDC_INITIAL_BALANCE - amountToReceive);
//    }
//
//    ///_swapSushiV3Multi///
//    // function test_swapSushiV3MultiMock() public {
//    //     helper();
//
//    //     uint24 poolFee = 500;
//
//    //     bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);
//
//    //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//    //     swapData[0] = IDexSwap.SwapData({
//    //         dexType: IDexSwap.DexType.SushiV3Multi,
//    //         fromToken: address(wEth),
//    //         fromAmount: 1*10**17,
//    //         toToken: address(mUSDC),
//    //         toAmount: 9*10**16,
//    //         toAmountMin: 9*10**16,
//    //         dexData: abi.encode(dexMock, path, address(Orchestrator), block.timestamp + 300)
//    //     });
//
//    //     vm.startPrank(Orchestrator);
//    //     wEth.approve(address(dex), 1*10**17);
//
//    //     assertEq(wEth.balanceOf(Orchestrator), ORCH_BALANCE);
//    //     assertEq(wEth.allowance(Orchestrator, address(dex)), 0.1 ether);
//
//    //     dex.conceroEntry(swapData, 0);
//
//    //     assertTrue(wEth.balanceOf(Orchestrator) > 0.09 ether);
//    // }
//
//    ///_swapUniV3Multi///
//    // function test_swapUniV3MultiMock() public {
//    //     helper();
//
//    //     uint24 poolFee = 500;
//
//    //     bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);
//
//    //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//    //     swapData[0] = IDexSwap.SwapData({
//    //         dexType: IDexSwap.DexType.UniswapV3Multi,
//    //         fromToken: address(wEth),
//    //         fromAmount: 1*10**17,
//    //         toToken: address(mUSDC),
//    //         toAmount: 1*10**6,
//    //         toAmountMin: 1*10**6,
//    //         dexData: abi.encode(dexMock, path, address(Orchestrator))
//    //     });
//
//    //     vm.startPrank(Orchestrator);
//    //     wEth.approve(address(dex), 1*10**17);
//
//    //     dex.conceroEntry(swapData, 0);
//
//    // }
//
//    ///_swapDrome///
//    ///OK
//    // function test_swapDromeMock() public {
//    //     helper();
//
//    //     assertEq(wEth.balanceOf(Orchestrator), ORCH_BALANCE);
//
//    //     uint256 amountToDeposit = 1*10**17;
//    //     uint256 amountToReceive = 1*10**5;
//
//    //     IRouter.Route[] memory route = new IRouter.Route[](1);
//
//    //     IRouter.Route memory routes = IRouter.Route({
//    //         from: address(wEth),
//    //         to: address(mUSDC),
//    //         stable: false,
//    //         factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
//    //     });
//
//    //     route[0] = routes;
//
//    //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//    //     swapData[0] = IDexSwap.SwapData({
//    //         dexType: IDexSwap.DexType.Aerodrome,
//    //         fromToken: address(wEth),
//    //         fromAmount: amountToDeposit,
//    //         toToken: address(mUSDC),
//    //         toAmount: amountToReceive,
//    //         toAmountMin: amountToReceive,
//    //         dexData: abi.encode(dexMock, route, Barba, block.timestamp + 1800)
//    //     });
//
//    //     vm.startPrank(Orchestrator);
//    //     wEth.approve(address(dex), 1 ether);
//
//    //     assertEq(mUSDC.balanceOf(address(dexMock)), USDC_INITIAL_BALANCE);
//
//    //     dex.conceroEntry(swapData, 0);
//
//    //     assertEq(wEth.balanceOf(address(dex)), 0);
//    // }
//
//    //_swapEtherOnUniV2Like//
//    // function test_swapEtherOnUniV2Like() public {
//    //     //===== Mock the value.
//    //             //In this case, the value is passed as a param through the function
//    //             //Also is transferred in the call
//    //     uint256 amountToSend = 0.1 ether;
//
//    //     //===== Mock the data for payload to send to the function
//    //     uint amountOutMin = 270*10**6;
//    //     address[] memory path = new address[](2);
//    //     path[0] = address(wEth);
//    //     path[1] = address(mUSDC);
//    //     address to = address(Orchestrator);
//    //     uint deadline = block.timestamp + 1800;
//
//    //     //===== Gives Orchestrator some ether and checks the balance
//    //     vm.deal(Orchestrator, ORCH_BALANCE);
//    //     assertEq(Orchestrator.balance, ORCH_BALANCE);
//
//    //     //===== Mock the payload to send on the function
//    //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//    //     swapData[0] = IDexSwap.SwapData({
//    //         dexType: IDexSwap.DexType.UniswapV2Ether,
//    //         fromToken: address(wEth),
//    //         fromAmount: amountToSend,
//    //         toToken: address(mUSDC),
//    //         toAmount: amountOutMin,
//    //         toAmountMin: amountOutMin,
//    //         dexData: abi.encode(dexMock, path, to, deadline)
//    //     });
//
//    //     //===== Start transaction calling the function and passing the payload
//    //     vm.startPrank(Orchestrator);
//    //     dex.conceroEntry{value: amountToSend}(swapData, amountToSend);
//    //     vm.stopPrank();
//
//    //     assertEq(Orchestrator.balance, 9.9 ether);
//    //     assertTrue(mUSDC.balanceOf(address(Orchestrator)) > 350*10**6);
//    // }
//}
