// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DexSwapScript} from "../../script/DexSwapScript.s.sol";
import {DexSwap} from "../../src/DexSwap.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {IRouter} from "@velodrome/contracts/interfaces/IRouter.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {ISwapRouter02, IV3SwapRouter} from "../../src/Interfaces/ISwapRouter02.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract DexSwapTest is Test {
    DexSwapScript public deploy;
    DexSwap public dex;

    IWETH wEth;
    IERC20 USDC;
    ERC20Mock AERO;

    IUniswapV2Router02 uniswapV2;
    IUniswapV2Router02 sushiV2;
    ISwapRouter02 uniswapV3;
    ISwapRouter sushiV3;
    IRouter aerodromeRouter;

    ERC20Mock tUSDC;

    address Orchestrator = makeAddr("Orchestrator");
    address Barba = makeAddr("Barba");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 private baseMainFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    uint256 private constant INITIAL_BALANCE = 10 ether;

    function setUp() public {
        baseMainFork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(baseMainFork);

        uniswapV2 = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        sushiV2 = IUniswapV2Router02(0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891);
        uniswapV3 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        sushiV3 = ISwapRouter(0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f);
        aerodromeRouter = IRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);


        wEth = IWETH(0x4200000000000000000000000000000000000006);
        USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        AERO = ERC20Mock(0x940181a94A35A4569E4529A3CDfB74e38FD98631);

        deploy = new DexSwapScript();
        dex = deploy.run();
        vm.makePersistent(address(dex));

        vm.prank(defaultSender);
        dex.transferOwnership(Barba);

        vm.startPrank(Barba);
        dex.manageOrchestratorContract(Orchestrator);
        dex.manageRouterAddress(address(uniswapV2), 1);
        dex.manageRouterAddress(address(sushiV2), 1);
        dex.manageRouterAddress(address(uniswapV3), 1);
        dex.manageRouterAddress(address(sushiV3), 1);
        dex.manageRouterAddress(address(aerodromeRouter), 1);

        //Only to test dustCollector
        tUSDC = new ERC20Mock("Teste USDC", "tUSDC", Barba, INITIAL_BALANCE);
        tUSDC.mint(address(dex), INITIAL_BALANCE);
        vm.stopPrank();
    }

    function helper() public {
        vm.deal(Orchestrator, INITIAL_BALANCE);

        assertEq(Orchestrator.balance, INITIAL_BALANCE);
        assertEq(wEth.balanceOf(Orchestrator), 0);

        vm.prank(Orchestrator);
        wEth.deposit{value: INITIAL_BALANCE}();

        assertEq(wEth.balanceOf(Orchestrator), INITIAL_BALANCE);
    }

    function test_CanSelectFork() public {
        // select the fork
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

    }

    ///manageOrchestratorContract///
    event DexSwap_OrchestratorContractUpdated(address previousAddress, address orchestrator);
    function test_manageOrchestrator() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit DexSwap_OrchestratorContractUpdated(Orchestrator, Orchestrator);
        dex.manageOrchestratorContract(Orchestrator);
    }

    ///manageRouterAddress////
    event DexSwap_NewRouterAdded(address router, uint256 isAllowed);
    function test_manageRouterAddress() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit DexSwap_NewRouterAdded(0x425141165d3DE9FEC831896C016617a52363b687, 1);
        dex.manageRouterAddress(0x425141165d3DE9FEC831896C016617a52363b687, 1);
    }

    ///dustRemoval///
    event DexSwap_RemovingDust(address caller, uint256 amount);
    function test_dustRemoval() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit DexSwap_RemovingDust(Barba, INITIAL_BALANCE);
        dex.dustRemoval(address(tUSDC), INITIAL_BALANCE);
    }

    ///dustEtherRemoval///
    function test_dustEtherRemoval() public {
        address newAddress = address(1);
        vm.deal(Barba, INITIAL_BALANCE);
        vm.deal(newAddress, 0);

        vm.prank(Barba);
        (bool sent,) = address(dex).call{value: 1 ether}("");
        if(!sent) revert();

        vm.prank(Barba);
        dex.dustEtherRemoval(newAddress);

        assertEq(newAddress.balance, 1 ether);
    }

    ///conceroEntry///
    function test_swapUniV2Like() public {
        helper();

        uint amountIn = 0.1 ether;
        uint amountOutMin = 270*10**6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(USDC);
        address to = address(Orchestrator);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), 0.1 ether);

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
                            dexType: DexSwap.DexType.UniswapV2,
                            dexData: abi.encode(sushiV2, amountIn, amountOutMin, path, to, deadline)
                        });
                    
        dex.conceroEntry(swapData, 0);

        assertEq(wEth.balanceOf(address(Orchestrator)), 9.9 ether);
        assertEq(wEth.balanceOf(address(dex)), 0);
        assertTrue(USDC.balanceOf(address(Orchestrator)) > 270*10**6);
    }

    ///_swapSushiV3Single///
    ///OK
    function test_swapSushiV3Single() public {
        helper();

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
                            dexType: DexSwap.DexType.SushiV3Single,
                            dexData: abi.encode(sushiV3, address(wEth), address(USDC), 500, address(Orchestrator), block.timestamp + 1800, 1*10**17, 120*10**6, 0)
                        });

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), 1 ether);
    
        dex.conceroEntry(swapData, 0);

        assertEq(wEth.balanceOf(address(Orchestrator)), 9.9 ether);
        assertEq(wEth.balanceOf(address(dex)), 0);
        assertTrue(USDC.balanceOf(address(Orchestrator)) > 120*10**6);
    }

    ///_swapUniV3Single///
    ///OK
    function test_swapUniV3Single() public {
        helper();

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
            dexType: DexSwap.DexType.UniswapV3Single,
            dexData: abi.encode(uniswapV3, address(wEth), address(USDC), 500, address(Orchestrator), 1*10**17, 260*10**6, 0)
        });

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), 1*10**17);
    
        dex.conceroEntry(swapData, 0);

        assertEq(wEth.balanceOf(address(Orchestrator)), 9.9 ether);
        assertEq(wEth.balanceOf(address(dex)), 0);
        assertTrue(USDC.balanceOf(address(Orchestrator)) > 260*10**6);
    }

    ///_swapSushiV3Multi///
    function test_swapSushiV3Multi() public {
        helper();

        uint24 poolFee = 500;

        bytes memory path = abi.encodePacked(wEth, poolFee, USDC, poolFee, wEth);

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
            dexType: DexSwap.DexType.SushiV3Multi,
            dexData: abi.encode(sushiV3, address(wEth), path, address(Orchestrator), block.timestamp + 300,1*10**17, 9*10**16)
        });

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), 1*10**17);

        assertEq(wEth.balanceOf(Orchestrator), INITIAL_BALANCE);
        assertEq(wEth.allowance(Orchestrator, address(dex)), 0.1 ether);
    
        dex.conceroEntry(swapData, 0);

        assertTrue(wEth.balanceOf(Orchestrator) > 0.09 ether);
    }

    ///_swapUniV3Multi///
    function test_swapUniV3Multi() public {
        helper();

        uint24 poolFee = 500;

        bytes memory path = abi.encodePacked(wEth, poolFee, USDC, poolFee, wEth);

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
            dexType: DexSwap.DexType.UniswapV3Multi,
            dexData: abi.encode(uniswapV3, address(wEth), path, address(Orchestrator), 1*10**17, 9*10**16)
        });

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), 1*10**17);

        assertEq(wEth.balanceOf(Orchestrator), INITIAL_BALANCE);
        assertEq(wEth.allowance(Orchestrator, address(dex)), 0.1 ether);
    
        dex.conceroEntry(swapData, 0);

        assertTrue(wEth.balanceOf(Orchestrator) > 0.09 ether);
    }

    ///_swapDrome///
    ///OK
    function test_swapDrome() public {
        vm.selectFork(baseMainFork);

        vm.deal(Orchestrator, INITIAL_BALANCE);

        assertEq(Orchestrator.balance, INITIAL_BALANCE);
        assertEq(wEth.balanceOf(Orchestrator), 0);

        vm.prank(Orchestrator);
        wEth.deposit{value: INITIAL_BALANCE}();

        assertEq(wEth.balanceOf(Orchestrator), INITIAL_BALANCE);

        IRouter.Route[] memory route = new IRouter.Route[](1);

        IRouter.Route memory routes = IRouter.Route({
            from: address(wEth),
            to: address(AERO),
            stable: false,
            factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
        });

        route[0] = routes;

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
            dexType: DexSwap.DexType.Aerodrome,
            dexData: abi.encode(aerodromeRouter, 0.93 ether , 280 ether, route, Barba, block.timestamp + 1800)
        });

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), 1 ether);
    
        dex.conceroEntry(swapData, 0);

        assertEq(wEth.balanceOf(address(dex)), 0);
        assertTrue(AERO.balanceOf(Barba) > 280 ether );
    }

    //multiple swaps in different DEXes
    function test_swapInDifferentDEXes() public {
        vm.selectFork(baseMainFork);

        vm.deal(Orchestrator, INITIAL_BALANCE);

        assertEq(Orchestrator.balance, INITIAL_BALANCE);
        assertEq(wEth.balanceOf(Orchestrator), 0);

        vm.prank(Orchestrator);
        wEth.deposit{value: INITIAL_BALANCE}();

        assertEq(wEth.balanceOf(Orchestrator), INITIAL_BALANCE);

        //======= Velodrome

        IRouter.Route[] memory route = new IRouter.Route[](1);

        IRouter.Route memory routes = IRouter.Route({
            from: address(wEth),
            to: address(AERO),
            stable: false,
            factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
        });

        route[0] = routes;

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](2);
        swapData[0] = DexSwap.SwapData({
            dexType: DexSwap.DexType.Aerodrome,
            dexData: abi.encode(aerodromeRouter, 0.93 ether , 280 ether, route, address(Orchestrator), block.timestamp + 1800)
        });

        //======== Uniswap V3 Multi
        
        uint24 poolFee = 500;

        bytes memory path = abi.encodePacked(wEth, poolFee, USDC, poolFee, wEth);

        swapData[1] = DexSwap.SwapData({
            dexType: DexSwap.DexType.UniswapV3Multi,
            dexData: abi.encode(uniswapV3, address(wEth), path, address(Orchestrator), 1*10**17, 9*10**16)
        });

        //======== Create the Array

        vm.startPrank(Orchestrator);
        wEth.approve(address(dex), INITIAL_BALANCE);
    
        dex.conceroEntry(swapData, 0);

        assertEq(wEth.balanceOf(address(dex)), 0);
        assertTrue(AERO.balanceOf(Orchestrator) > 280 ether );

        assertTrue(wEth.balanceOf(Orchestrator) > 0.09 ether);

    }

    //_swapEtherOnUniV2Like//
    function test_swapEtherOnUniV2Like() public {
        //===== Mock the value.
                //In this case, the value is passed as a param through the function
                //Also is transferred in the call
        uint256 amountToSend = 0.1 ether;

        //===== Mock the data for payload to send to the function
        uint amountOutMin = 270*10**6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(USDC);
        address to = address(Orchestrator);
        uint deadline = block.timestamp + 1800;

        //===== Gives Orchestrator some ether and checks the balance
        vm.deal(Orchestrator, INITIAL_BALANCE);
        assertEq(Orchestrator.balance, INITIAL_BALANCE);

        //===== Mock the payload to send on the function
        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = DexSwap.SwapData({
                            dexType: DexSwap.DexType.UniswapV2Ether,
                            dexData: abi.encode(uniswapV2, amountOutMin, path, to, deadline)
                        });

        //===== Start transaction calling the function and passing the payload
        vm.startPrank(Orchestrator);                    
        dex.conceroEntry{value: amountToSend}(swapData, amountToSend);
        vm.stopPrank();

        assertEq(Orchestrator.balance, 9.9 ether);
        assertTrue(USDC.balanceOf(address(Orchestrator)) > 350*10**6);
    }
}