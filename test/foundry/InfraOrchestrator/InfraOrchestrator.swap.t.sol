// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Test} from "forge-std/src/Test.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/src/console.sol";
import {DeployInfraScript} from "../scripts/DeployInfra.s.sol";

contract DexSwapTest is Test {
    // @notice helper vars
    address internal constant NATIVE_TOKEN = address(0);
    IInfraOrchestrator.Integration internal emptyIntegration =
        IInfraOrchestrator.Integration({integrator: address(0), feeBps: 0});

    address internal infraProxy;

    modifier selectFork(uint256 forkId) {
        DeployInfraScript deployInfraScript = new DeployInfraScript();
        infraProxy = deployInfraScript.run(forkId);
        _;
    }

    function testFork_Univ3OnBaseViaRangoRouting()
        public
        selectFork(vm.createFork(vm.envString("BASE_RPC_URL")))
    {
        uint256 fromAmount = 0.1 ether;
        uint256 toAmount = 267.528449e6;
        uint256 toAmountMin = 266.190806e6;
        address user = makeAddr("user");

        deal(user, fromAmount);

        bytes
            memory dexData = hex"7ff36ab5000000000000000000000000000000000000000000000000000000000fddbfd70000000000000000000000000000000000000000000000000000000000000080000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673fb53400000000000000000000000000000000000000000000000000000000000000020000000000000000000000004200000000000000000000000000000000000006000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913";

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexRouter: vm.envAddress("ALIENBASE_ROUTER_BASE"),
            fromToken: NATIVE_TOKEN,
            fromAmount: fromAmount,
            toToken: vm.envAddress("USDC_BASE"),
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            dexData: dexData
        });

        vm.prank(user);
        InfraOrchestrator(payable(infraProxy)).swap{value: fromAmount}(
            swapData,
            user,
            emptyIntegration
        );
    }

    //    address internal constant ETH_TOKEN = address(0);
    //    address internal constant POL_TOKEN = address(0);
    //
    //    // Base tokens
    //    address internal usdcTokenBase = vm.envAddress("USDC_BASE");
    //    address internal wethTokenBase = vm.envAddress("WETH_BASE");
    //    address internal daiTokenBase = vm.envAddress("DAI_BASE");
    //    address internal sushiTokenBase = vm.envAddress("SUSHI_BASE");
    //    address internal oneInchTokenBase = vm.envAddress("1INCH_BASE");
    //
    //    //Arbitrum tokens
    //    address internal usdcTokenArbitrum = vm.envAddress("USDC_ARBITRUM");
    //    address internal usdtTokenArbitrum = vm.envAddress("USDT_ARBITRUM");
    //    address internal wethTokenArbitrum = vm.envAddress("WETH_ARBITRUM");
    //
    //    //Polygon tokens
    //    address internal usdcTokenPolygon = vm.envAddress("USDC_POLYGON");
    //    address internal wethTokenPolygon = vm.envAddress("WETH_POLYGON");
    //
    //    //Avalanche tokens
    //    address internal usdcTokenAvalanche = vm.envAddress("USDC_AVALANCHE");
    //    address internal wavaxTokenAvalanche = vm.envAddress("WAVAX_AVALANCHE");
    //
    //    //Arbitrum Routers
    //    address internal sushiRouterArbitrum = vm.envAddress("SUSHISWAP_ROUTER_ARBITRUM_ADDRESS");
    //    address internal uniV3RouterArbitrum = vm.envAddress("UNI_V3_ROUTER_ARBITRUM_ADDRESS");
    //    address internal paraSwapV5RouterArbitrum =
    //        vm.envAddress("PARASWAP_V5_ROUTER_ARBITRUM_ADDRESS");
    //
    //    //Base Routers
    //    address internal uniV3RouterBase = vm.envAddress("UNI_V3_ROUTER02_BASE_ADDRESS");
    //    address internal paraSwapV6_2RouterBase = vm.envAddress("PARASWAP_V6_2_ROUTER_BASE_ADDRESS");
    //    address internal odosRouterV2Base = vm.envAddress("ODOS_ROUTER_V2_BASE_ADDRESS");
    //    address internal oneInchRouterV5Base = vm.envAddress("1INCH_ROUTER_V5_BASE_ADDRESS");
    //    address internal curveRouterBase = vm.envAddress("CURVE_ROUTER_BASE_ADDRESS");
    //    address internal alienbaseRouterBase = vm.envAddress("ALIENBASE_ROUTER_BASE_ADDRESS");
    //
    //    //Polygon Routers
    //    address internal quickSwapRouterPolygon = vm.envAddress("QUICKSWAP_ROUTER_POLYGON_ADDRESS");
    //
    //    //Avalanche Routers
    //    address internal pangolinRouterAvalanche = vm.envAddress("PANGOLIN_ROUTER_AVALANCHE_ADDRESS");
    //
    //    address payable internal sender = payable(makeAddr("sender"));
    //    address internal integrator = makeAddr("integrator");
    //
    //    modifier addRouterInWhiteList(address router, address proxy) {
    //        _allowRouter(router, address(proxy));
    //        _;
    //    }
    //
    //    function setUp() public override setFork(polygonAnvilForkId) {
    //        super.setUp();
    //    }
    //
    //    ////////////////////  Base ///////////////////////////////
    //    ////////////////////  Block number 22713659 //////////////
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////      Alienbase     ////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //passed
    //    function test_dexSwapAlienbaseRouterETHToUSDCBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(alienbaseRouterBase, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.1 ether;
    //        uint256 toAmount = 267.528449e6;
    //        uint256 toAmountMin = 266.190806e6;
    //
    //        bytes
    //            memory dexData = hex"7ff36ab5000000000000000000000000000000000000000000000000000000000fddbfd70000000000000000000000000000000000000000000000000000000000000080000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673fb53400000000000000000000000000000000000000000000000000000000000000020000000000000000000000004200000000000000000000000000000000000006000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: alienbaseRouterBase,
    //            fromToken: ETH_TOKEN,
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapAlienbaseRouterUSDCToWETHBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(alienbaseRouterBase, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 10e6; //10 usdc
    //        uint256 toAmount = 0.002945698049459263e18;
    //        uint256 toAmountMin = 0.002930969559211966e18;
    //
    //        bytes
    //            memory dexData = hex"38ed173900000000000000000000000000000000000000000000000000000000009834e7000000000000000000000000000000000000000000000000000a69b3876c9fbe00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673fb6140000000000000000000000000000000000000000000000000000000000000002000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000004200000000000000000000000000000000000006";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: alienbaseRouterBase,
    //            fromToken: usdcTokenBase,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapAlienbaseRouterUSDCToETHBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(alienbaseRouterBase, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 10e6;
    //        uint256 toAmount = 0.002945698049459263 ether;
    //        uint256 toAmountMin = 0.002930969559211966 ether;
    //
    //        bytes
    //            memory dexData = hex"18cbafe500000000000000000000000000000000000000000000000000000000009834e7000000000000000000000000000000000000000000000000000a69b3876c9fbe00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673fb67c0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000004200000000000000000000000000000000000006";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: alienbaseRouterBase,
    //            fromToken: usdcTokenBase,
    //            fromAmount: fromAmount,
    //            toToken: ETH_TOKEN,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////      Curve     ////////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //passed
    //    function test_dexSwapCurveRouterUSDCToWETHBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(curveRouterBase, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 10e6; //1 usdc
    //        uint256 toAmount = 0.002950528095025959e18;
    //        uint256 toAmountMin = 0.002935775454550829e18;
    //
    //        bytes
    //            memory dexData = hex"c872a3c5000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000f6c5f01c7f3148891ad0e19df78743d31e390d1f000000000000000000000000417ac0e078398c154edfadd9ef675d30be60af930000000000000000000000006e53131f68a034873b6bfa15502af094ef0c58540000000000000000000000004200000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009834e7000000000000000000000000000000000000000000000000000a6e127d1bdb2d000000000000000000000000f6c5f01c7f3148891ad0e19df78743d31e390d1f0000000000000000000000006e53131f68a034873b6bfa15502af094ef0c5854000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: curveRouterBase,
    //            fromToken: usdcTokenBase,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //not working
    //    function test_dexSwapCurveRouterETHToUSDCBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(curveRouterBase, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.0003 ether;
    //        uint256 toAmount = 0.993336e6;
    //        uint256 toAmountMin = 0.988369e6;
    //
    //        bytes
    //            memory dexData = hex"c872a3c5000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000420000000000000000000000000000000000000600000000000000000000000042000000000000000000000000000000000000060000000000000000000000006e53131f68a034873b6bfa15502af094ef0c5854000000000000000000000000417ac0e078398c154edfadd9ef675d30be60af93000000000000000000000000f6c5f01c7f3148891ad0e19df78743d31e390d1f000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001102aacc5688000000000000000000000000000000000000000000000000000000000000f14d100000000000000000000000042000000000000000000000000000000000000060000000000000000000000006e53131f68a034873b6bfa15502af094ef0c5854000000000000000000000000f6c5f01c7f3148891ad0e19df78743d31e390d1f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: curveRouterBase,
    //            fromToken: ETH_TOKEN,
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapCurveRouterUSDCToETHBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(curveRouterBase, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6;
    //        uint256 toAmount = 0.00029502055232845 ether;
    //        uint256 toAmountMin = 0.000293545449566807 ether;
    //
    //        bytes
    //            memory dexData = hex"c872a3c5000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000f6c5f01c7f3148891ad0e19df78743d31e390d1f000000000000000000000000417ac0e078398c154edfadd9ef675d30be60af930000000000000000000000006e53131f68a034873b6bfa15502af094ef0c585400000000000000000000000042000000000000000000000000000000000000060000000000000000000000004200000000000000000000000000000000000006000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000010afa71c98c9d000000000000000000000000f6c5f01c7f3148891ad0e19df78743d31e390d1f0000000000000000000000006e53131f68a034873b6bfa15502af094ef0c5854000000000000000000000000420000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: curveRouterBase,
    //            fromToken: usdcTokenBase,
    //            fromAmount: fromAmount,
    //            toToken: ETH_TOKEN,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //////////////////////////////////////////////////////////
    //    ////////////////// Odos Router V2 ////////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //passed
    //    function test_dexSwapOdosRouterV2USDCToWETHBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(odosRouterV2Base, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.000295473686245412e18;
    //        uint256 toAmountMin = 0.000293996317814184e18;
    //
    //        bytes
    //            memory dexData = hex"83bd37f900040002030f387e07010cbb65c26b5000c49b00017882570840a97a490a37bd8db9e1ae39165bfbd600000001cd1722f3947def4cf144679da39c4c32bdc356810000000003010203000a0101010200ff000000000000000000000000000000000000000000883e4ae0a817f2901500971b353b5dd89aa52184833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: odosRouterV2Base,
    //            fromToken: usdcTokenBase,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //doesnt work with native
    //    function test_dexSwapOdosRouterV2ETHToUSDCBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(odosRouterV2Base, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.001 ether;
    //        uint256 toAmount = 3.355603e6;
    //        uint256 toAmountMin = 3.338824e6;
    //
    //        bytes
    //            memory dexData = hex"83bd37f90000000407038b38ea920700033333d300c49b00017882570840a97a490a37bd8db9e1ae39165bfbd600000001cd1722f3947def4cf144679da39c4c32bdc35681000000000301020300040101022b000101010201ff000000000000000000000000000000005b52dfa81e7409df9390c9403aceb51ea3df4f204200000000000000000000000000000000000006000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: odosRouterV2Base,
    //            fromToken: ETH_TOKEN,
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////  1Inch ////////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    function test_dexSwap1InchV5USDCTo1InchTokenBase()
    //        public
    //        setFork(baseAnvilForkId)
    //        addRouterInWhiteList(oneInchRouterV5Base, address(baseOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 10e6; //10 usdc
    //        uint256 toAmount = 29.186618652079786377e18;
    //        uint256 toAmountMin = 29.040685558819387445e18;
    //
    //        bytes
    //            memory dexData = hex"12aa3caf000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000c5fecc3a29fb57b5024eec8a2239d4621e111cbe000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000009834e700000000000000000000000000000000000000000000000193053da6cf3ef835000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004af00000000000000000000000000000000000000000000000000000000049100a007e5c0d200000000000000000000000000000000000000000000046d00040a0003f0512003c01acae3d0173a93d819efdc832c7c4f153b06833589fcd6edb6e08f4c7c32d4f71b54bda02913016452bbbe2900000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000673f9a44def66c6c178087fd931514e99b04479e4d3d956c0002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009834e700000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000062769914a469c00000000000000000000000000000000000000000000000000000000673f9a4400000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000005af3107a400000000000000000b671b09bd7eb7a242300000000000000008bd0c186893c2c000000000000000dd975ede04e7dbbc0000000000000000005aab64d6906dbaed800000000000000000000000000000000000000000004ee7259d6914ae6c461bc00000000000000004563918244f400000000000000000000006a94d74f430000000000000000000000000000673f99ea000000000000000000003b1dfde910000000000000000000000000000000000000000000000000000000000000000041b0087e9968881cc03a4f3270b3086fd3a18f6587c3179ad985c8c406056d7b98035f5800bbb63a992a30c39c7224be035751091573a74d263682a8536b8d51711c0000000000000000000000000000000000000000000000000000000000000040414200000000000000000000000000000000000006d0e30db002a000000000000000000000000000000000000000000000000190fec846c67c66e1ee63c1e5814af5a3adb853290bc9f909138fbf1a3c3feb086842000000000000000000000000000000000000061111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000007787a5c8";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: oneInchRouterV5Base,
    //            fromToken: usdcTokenBase,
    //            fromAmount: fromAmount,
    //            toToken: oneInchTokenBase,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(baseOrchestratorProxy));
    //    }
    //
    //    //////////////////// Arbitrum ////////////////////////////
    //    //////////////////// Block number 276843772 //////////////
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////  Sushi Swap ///////////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //passed
    //    function test_dexSwapSushiSwapRouterUSDCToUSDT()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(sushiRouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.993041e6;
    //        uint256 toAmountMin = 0.988075e6;
    //
    //        bytes
    //            memory dexData = hex"38ed173900000000000000000000000000000000000000000000000000000000000f381a00000000000000000000000000000000000000000000000000000000000f13ac00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673f6a920000000000000000000000000000000000000000000000000000000000000003000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: sushiRouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: usdtTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapSushiSwapRouterUSDCToWETH()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(sushiRouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.00029991786617675e18;
    //        uint256 toAmountMin = 0.000298418276845866e18;
    //
    //        bytes
    //            memory dexData = hex"38ed173900000000000000000000000000000000000000000000000000000000000f381a00000000000000000000000000000000000000000000000000010f68f44ac36b00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673f697d0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: sushiRouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapSushiSwapRouterUSDCToETH()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(sushiRouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //usdc
    //        uint256 toAmount = 0.00029991786617675 ether;
    //        uint256 toAmountMin = 0.000298418276845866 ether;
    //
    //        bytes
    //            memory dexData = hex"18cbafe500000000000000000000000000000000000000000000000000000000000f381a00000000000000000000000000000000000000000000000000010f68f44ac36b00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673f69fe0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: sushiRouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: address(0),
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapSushiSwapRouterETHToUSDC()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(sushiRouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.0001 ether; //ETH
    //        uint256 toAmount = 0.33059e6; //usdc
    //        uint256 toAmountMin = 0.328937e6; //usdc
    //
    //        bytes
    //            memory dexData = hex"7ff36ab500000000000000000000000000000000000000000000000000000000000504e90000000000000000000000000000000000000000000000000000000000000080000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000673f6b16000000000000000000000000000000000000000000000000000000000000000200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: sushiRouterArbitrum,
    //            fromToken: address(0),
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////     Uniswap     ///////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //passed
    //    function test_dexSwapUniSwapRouterUSDCToUSDT()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(uniV3RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.996903e6;
    //        uint256 toAmountMin = 0.991918e6;
    //
    //        bytes
    //            memory dexData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000001934fbb778500000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000000000000f22af000000000000000000000000000000000000000000000000000000000000002baf88d065e77c8cc2239327c5edb3a432268e5831000064fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: uniV3RouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: usdtTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapUniSwapRouterUSDCToWETH()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(uniV3RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.000299377182115898e18;
    //        uint256 toAmountMin = 0.000297880296205318e18;
    //
    //        bytes
    //            memory dexData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000001934fbd59aa00000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000010eebbb0ca1e0000000000000000000000000000000000000000000000000000000000000002baf88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: uniV3RouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapUniSwapRouterUSDCToETH()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(uniV3RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //usdc
    //        uint256 toAmount = 0.000300419724797236 ether;
    //        uint256 toAmountMin = 0.000298917626173249 ether;
    //
    //        bytes
    //            memory dexData = hex"ac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001934fb896d900000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000010fdd40cbad5d000000000000000000000000000000000000000000000000000000000000002baf88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004449404b7c00000000000000000000000000000000000000000000000000010fdd2eecd741000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: uniV3RouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: address(0),
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapUniSwapRouterETHToUSDC()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(uniV3RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.0001 ether; //ETH
    //        uint256 toAmount = 0.331996e6; //usdc
    //        uint256 toAmountMin = 0.330336e6; //usdc
    //
    //        bytes
    //            memory dexData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000001934fad171000000000000000000000000000000000000000000000000000005ab8e441cd800000000000000000000000000000000000000000000000000000000000050a60000000000000000000000000000000000000000000000000000000000000002b82af49447d8a07e3bd95bd0d56f35241523fbab10001f4af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: uniV3RouterArbitrum,
    //            fromToken: address(0),
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////  ParaSwap      ////////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //does not work
    //    function test_dexSwapParaSwapRouterUSDCToUSDT()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(paraSwapV5RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.996903e6;
    //        uint256 toAmountMin = 0.991918e6;
    //
    //        bytes
    //            memory dexData = hex"ac9650d80000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000001934fbb778500000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000000000000f22af000000000000000000000000000000000000000000000000000000000000002baf88d065e77c8cc2239327c5edb3a432268e5831000064fd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: paraSwapV5RouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: usdtTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //does not work
    //    function test_dexSwapParaSwapRouterUSDCToWETH() public setFork(arbitrumAnvilForkId) {
    //        _allowRouter(paraSwapV5RouterArbitrum, address(arbitrumOrchestratorProxy));
    //
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.00029758021792574 ether;
    //        uint256 toAmountMin = 0.000296092316836111 ether;
    //
    //        bytes
    //            memory dexData = hex"54e3f31b0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000010d4b6f1016c900000000000000000000000000000000000000000000000000010ea5dcf7ba4600000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000003800000000000000000000000000000000000000000000000000000000000000400000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000673f779551436a490fb745e4a0a79829c8000ce6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000ed9e3f98bbed560e66b89aac922e29d4596a96420000000000000000000000000000000000000000000000000000000000000108a9059cbb000000000000000000000000ed9e3f98bbed560e66b89aac922e29d4596a964200000000000000000000000000000000000000000000000000000000000f387e7dc20382000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000f387e0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000def171fe48cf0115b1d80b88dc8eab59176fee57000000000000000000000000d5b927956057075377263aab7f8afc12f85100db00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000001080000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: paraSwapV5RouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //does not work
    //    function test_dexSwapParaSwapRouterUSDCToETH()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(paraSwapV5RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //usdc
    //        uint256 toAmount = 0.000300419724797236 ether;
    //        uint256 toAmountMin = 0.000298917626173249 ether;
    //
    //        bytes
    //            memory dexData = hex"ac9650d800000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000124c04b8d59000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001934fb896d900000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000010fdd40cbad5d000000000000000000000000000000000000000000000000000000000000002baf88d065e77c8cc2239327c5edb3a432268e58310001f482af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004449404b7c00000000000000000000000000000000000000000000000000010fdd2eecd741000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: paraSwapV5RouterArbitrum,
    //            fromToken: usdcTokenArbitrum,
    //            fromAmount: fromAmount,
    //            toToken: address(0),
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //does not work
    //    function test_dexSwapParaSwapRouterETHToUSDC()
    //        public
    //        setFork(arbitrumAnvilForkId)
    //        addRouterInWhiteList(paraSwapV5RouterArbitrum, address(arbitrumOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.001 ether; //ETH
    //        uint256 toAmount = 3.334998e6; //usdc
    //        uint256 toAmountMin = 3.318323e6; //usdc
    //
    //        bytes
    //            memory dexData = hex"54e3f31b0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000038b38ea920700000000000000000000000000000000000000000000000000000000000032a1e5000000000000000000000000000000000000000000000000000000000032e30700000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000440000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc356810000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000004c000000000000000000000000000000000000000000000000000000000673f7930962cd732e34c45a093489154807ea37000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000ed9e3f98bbed560e66b89aac922e29d4596a9642000000000000000000000000000000000000000000000000000000000000010cd0e30db0a9059cbb000000000000000000000000ed9e3f98bbed560e66b89aac922e29d4596a964200000000000000000000000000000000000000000000000000038b38ea9207007dc2038200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000000000000000000000000000038b38ea9207000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000def171fe48cf0115b1d80b88dc8eab59176fee57000000000000000000000000d5b927956057075377263aab7f8afc12f85100db00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000048000000000000000000000000000000000000000000000000000000000000010c000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000038b38ea920700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: paraSwapV5RouterArbitrum,
    //            fromToken: address(0),
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenArbitrum,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(arbitrumOrchestratorProxy));
    //    }
    //
    //    //////////////////// Polygon ////////////////////////////
    //    //////////////////// Block number 64588691 //////////////
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////     Quick Swap     ////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //passed
    //    function test_dexSwapQuickSwapRouterUSDCToWETH()
    //        public
    //        setFork(polygonAnvilForkId)
    //        addRouterInWhiteList(quickSwapRouterPolygon, address(polygonOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.000294773721275645e18;
    //        uint256 toAmountMin = 0.000293299852669266e18;
    //
    //        bytes
    //            memory dexData = hex"38ed173900000000000000000000000000000000000000000000000000000000000f387e00000000000000000000000000000000000000000000000000010ac13a4b12cf00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc35681000000000000000000000000000000000000000000000000000000006740511a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c33590000000000000000000000007ceb23fd6bc0add59e62ac25578270cff1b9f619";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: quickSwapRouterPolygon,
    //            fromToken: usdcTokenPolygon,
    //            fromAmount: fromAmount,
    //            toToken: wethTokenPolygon,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(polygonOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapQuickSwapRouterPOLToUSDC()
    //        public
    //        setFork(polygonAnvilForkId)
    //        addRouterInWhiteList(quickSwapRouterPolygon, address(polygonOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 0.001e18; //POL
    //        uint256 toAmount = 0.000457e6; //usdc
    //        uint256 toAmountMin = 0.000454e6; //usdc
    //
    //        bytes
    //            memory dexData = hex"7ff36ab500000000000000000000000000000000000000000000000000000000000001c70000000000000000000000000000000000000000000000000000000000000080000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000674056ac00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf12700000000000000000000000007ceb23fd6bc0add59e62ac25578270cff1b9f6190000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c3359";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: quickSwapRouterPolygon,
    //            fromToken: POL_TOKEN,
    //            fromAmount: fromAmount,
    //            toToken: usdcTokenPolygon,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(polygonOrchestratorProxy));
    //    }
    //
    //    //passed
    //    function test_dexSwapQuickSwapRouterUSDCToPOL()
    //        public
    //        setFork(polygonAnvilForkId)
    //        addRouterInWhiteList(quickSwapRouterPolygon, address(polygonOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //usdc
    //        uint256 toAmount = 2.16620982591814043e18; //pol
    //        uint256 toAmountMin = 2.155378776788549727e18; //pol
    //
    //        bytes
    //            memory dexData = hex"18cbafe500000000000000000000000000000000000000000000000000000000000f387e0000000000000000000000000000000000000000000000001de9728f133bb56100000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000674057b000000000000000000000000000000000000000000000000000000000000000020000000000000000000000003c499c542cef5e3811e1192ce70d8cc03d5c33590000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: quickSwapRouterPolygon,
    //            fromToken: usdcTokenPolygon,
    //            fromAmount: fromAmount,
    //            toToken: POL_TOKEN,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(polygonOrchestratorProxy));
    //    }
    //
    //    //////////////////// Avalanche ////////////////////////////
    //    //////////////////// Block number 53397798 //////////////
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////     Pangolin Swap     /////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    //doesnt work
    //    function test_dexSwapPangolinSwapRouterUSDCToWAVAX()
    //        public
    //        setFork(avalancheAnvilForkId)
    //        addRouterInWhiteList(pangolinRouterAvalanche, address(avalancheOrchestratorProxy))
    //    {
    //        uint256 fromAmount = 1e6; //1 usdc
    //        uint256 toAmount = 0.027249956050478939e18;
    //        uint256 toAmountMin = 0.027113706270226544e18;
    //
    //        bytes
    //            memory dexData = hex"38ed173900000000000000000000000000000000000000000000000000000000000f387e000000000000000000000000000000000000000000000000006053c8d8cb68b600000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000cd1722f3947def4cf144679da39c4c32bdc3568100000000000000000000000000000000000000000000000000000000674060d40000000000000000000000000000000000000000000000000000000000000003000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e00000000000000000000000060781c2586d68229fde47564546784ab3faca982000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c7";
    //
    //        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //        swapData[0] = IDexSwap.SwapData({
    //            dexRouter: pangolinRouterAvalanche,
    //            fromToken: usdcTokenAvalanche,
    //            fromAmount: fromAmount,
    //            toToken: wavaxTokenAvalanche,
    //            toAmount: toAmount,
    //            toAmountMin: toAmountMin,
    //            dexData: dexData
    //        });
    //
    //        _callTestWithRouter(swapData, address(avalancheOrchestratorProxy));
    //    }
    //
    //    //////////////////////////////////////////////////////////
    //    //////////////////     Utils     /////////////////////////
    //    //////////////////////////////////////////////////////////
    //
    //    function _callTestWithRouter(IDexSwap.SwapData[] memory swapData, address proxy) internal {
    //        console.log("block.number", block.number);
    //        console.log("fromAmount: ", swapData[0].fromAmount);
    //        console.log("toAmount: ", swapData[0].toAmount);
    //        console.log("toAmountMin: ", swapData[0].toAmountMin);
    //
    //        InfraOrchestrator orchestrator = InfraOrchestrator(payable(proxy));
    //
    //        IInfraOrchestrator.Integration memory integration = IInfraOrchestrator.Integration({
    //            integrator: integrator,
    //            feeBps: 0
    //        });
    //        bool isFromNative = swapData[0].fromToken == address(0);
    //        bool isToNative = swapData[0].toToken == address(0);
    //
    //        uint256 userBalanceFromTokenBefore;
    //        uint256 userBalanceFromTokenAfter;
    //        uint256 userBalanceToTokenBefore;
    //        uint256 userBalanceToTokenAfter;
    //
    //        if (isFromNative && !isToNative) {
    //            deal(sender, swapData[0].fromAmount);
    //
    //            userBalanceFromTokenBefore = sender.balance;
    //            userBalanceToTokenBefore = IERC20(swapData[0].toToken).balanceOf(sender);
    //
    //            vm.prank(sender);
    //            orchestrator.swap{value: swapData[0].fromAmount}(swapData, sender, integration);
    //
    //            userBalanceFromTokenAfter = sender.balance;
    //            userBalanceToTokenAfter = IERC20(swapData[0].toToken).balanceOf(sender);
    //        } else if (isToNative && !isFromNative) {
    //            _dealERC20AndApprove(swapData[0].fromToken, sender, swapData[0].fromAmount, proxy);
    //
    //            userBalanceFromTokenBefore = IERC20(swapData[0].fromToken).balanceOf(sender);
    //            userBalanceToTokenBefore = sender.balance;
    //
    //            vm.prank(sender);
    //            orchestrator.swap(swapData, sender, integration);
    //
    //            userBalanceFromTokenAfter = IERC20(swapData[0].fromToken).balanceOf(sender);
    //            userBalanceToTokenAfter = sender.balance;
    //        } else if (!isFromNative && !isToNative) {
    //            _dealERC20AndApprove(swapData[0].fromToken, sender, swapData[0].fromAmount, proxy);
    //
    //            userBalanceFromTokenBefore = IERC20(swapData[0].fromToken).balanceOf(sender);
    //            userBalanceToTokenBefore = IERC20(swapData[0].toToken).balanceOf(sender);
    //
    //            vm.prank(sender);
    //            orchestrator.swap(swapData, sender, integration);
    //
    //            userBalanceFromTokenAfter = IERC20(swapData[0].fromToken).balanceOf(sender);
    //            userBalanceToTokenAfter = IERC20(swapData[0].toToken).balanceOf(sender);
    //        }
    //
    //        console.log("userBalanceFromTokenBefore: ", userBalanceFromTokenBefore);
    //        console.log("userBalanceFromTokenAfter: ", userBalanceFromTokenAfter);
    //        console.log("userBalanceToTokenBefore: ", userBalanceToTokenBefore);
    //        console.log("userBalanceToTokenAfter: ", userBalanceToTokenAfter);
    //
    //        assertGt(userBalanceToTokenAfter, userBalanceToTokenBefore);
    //        assertLt(userBalanceFromTokenAfter, userBalanceFromTokenBefore);
    //    }
    //
    //    function _allowRouter(address router, address orchestratorProxy) internal {
    //        vm.prank(deployer);
    //        (bool success, ) = address(orchestratorProxy).call(
    //            abi.encodeWithSignature("setDexRouterAddress(address,bool)", router, true)
    //        );
    //        /// @dev assert it is set correctly
    //        (, bytes memory returnData) = address(orchestratorProxy).call(
    //            abi.encodeWithSignature("s_routerAllowed(address)", router)
    //        );
    //        bool returnedValue = abi.decode(returnData, (bool));
    //        assertEq(returnedValue, true);
    //    }
    //
    //    function _dealERC20AndApprove(
    //        address token,
    //        address _caller,
    //        uint256 _amount,
    //        address proxy
    //    ) internal {
    //        deal(token, _caller, _amount);
    //        vm.prank(_caller);
    //        IERC20(token).approve(proxy, _amount);
    //    }
}
