// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

//Foundry
import {Test, console} from "forge-std/Test.sol";
//Protocol Contacts
import {DexSwap} from "../../src/DexSwap.sol";
import {ConceroPool} from "../../src/ConceroPool.sol";
import {Concero} from "../../src/Concero.sol";
import {Orchestrator} from "../../src/Orchestrator.sol";
import {TransparentUpgradeableProxy} from "../../src/TransparentUpgradeableProxy.sol";

//Protocol Interfaces
import {IDexSwap} from "../../src/Interfaces/IDexSwap.sol";

//Protocol Storage
import {Storage} from "../../src/Libraries/Storage.sol";

//Deploy Scripts
import {DexSwapDeploy} from "../../script/DexSwapDeploy.s.sol";
import {ConceroPoolDeploy} from "../../script/ConceroPoolDeploy.s.sol";
import {ConceroDeploy} from "../../script/ConceroDeploy.s.sol";
import {OrchestratorDeploy} from "../../script/OrchestratorDeploy.s.sol";
import {TransparentDeploy} from "../../script/TransparentDeploy.s.sol";

//Mocks
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    //==== Instantiate Contracts
    DexSwap public dex;
    ConceroPool public pool;
    Concero public concero;
    Orchestrator public orch;
    Orchestrator public orchEmpty;
    TransparentUpgradeableProxy public proxy;

    //==== Instantiate Deploy Script
    DexSwapDeploy dexDeploy;
    ConceroPoolDeploy poolDeploy;
    ConceroDeploy conceroDeploy;
    OrchestratorDeploy orchDeploy;
    TransparentDeploy proxyDeploy;

    //==== Wrapped contract
    Orchestrator op;

    //==== Create the instance to forked tokens
    IWETH wEth;
    IERC20 public mUSDC;
    ERC20Mock AERO;

    //==== Instantiate DEXes Routers
    IUniswapV2Router02 uniswapV2;
    IUniswapV2Router02 sushiV2;
    ISwapRouter02 uniswapV3;
    ISwapRouter sushiV3;
    IRouter aerodromeRouter;

    //Base Mainnet variables
    address link = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address ccipRouter = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    uint64 ccipChainSelector = 15971525489660198786;
    address functionsRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
    bytes32 donId = 0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000;

    ERC20Mock tUSDC;

    address User = makeAddr("User");
    address Tester = makeAddr("Tester");
    address Messenger = makeAddr("Messenger");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 private baseMainFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant USDC_INITIAL_BALANCE = 10 * 10**6;

    function setUp() public {
        baseMainFork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(baseMainFork);

        uniswapV2 = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        sushiV2 = IUniswapV2Router02(0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891);
        uniswapV3 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        sushiV3 = ISwapRouter(0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f);
        aerodromeRouter = IRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);

        wEth = IWETH(0x4200000000000000000000000000000000000006);
        mUSDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        AERO = ERC20Mock(0x940181a94A35A4569E4529A3CDfB74e38FD98631);
        
        dexDeploy = new DexSwapDeploy();
        poolDeploy = new ConceroPoolDeploy();
        conceroDeploy = new ConceroDeploy();
        orchDeploy = new OrchestratorDeploy();
        proxyDeploy = new TransparentDeploy();
        
        //DEPLOY AN EMPTY ORCH
        orchEmpty = orchDeploy.run(
            functionsRouter,
            Messenger,
            address(0),
            address(0),
            address(0),
            address(0)
        );
        //====== Deploy the proxy with the Dummy Orch
        proxy = proxyDeploy.run(address(orchEmpty), Tester, "");
        
        dex = dexDeploy.run(address(proxy));
        pool = poolDeploy.run(
            link,
            ccipRouter,
            address(proxy)
        );
        concero = conceroDeploy.run(
            functionsRouter,
            0, //uint64 _donHostedSecretsVersion
            donId,
            2, //uint8 _donHostedSecretsSlotId
            0, //uint64 _subscriptionId,
            ccipChainSelector,
            1, //uint _chainIndex,
            link,
            ccipRouter,
            Storage.PriceFeeds ({
                linkToUsdPriceFeeds: 0x17CAb8FE31E32f08326e5E27412894e49B0f9D65,
                usdcToUsdPriceFeeds: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
                nativeToUsdPriceFeeds: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
                linkToNativePriceFeeds: 0xc5E65227fe3385B88468F9A01600017cDC9F3A12
            }),
            Storage.JsCodeHashSum ({
                src: 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124,
                dst: 0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173
            }),
            Messenger,
            address(pool),
            address(proxy)
        );

        orch = orchDeploy.run(
            functionsRouter,
            Messenger,
            address(dex),
            address(concero),
            address(pool),
            address(proxy)
        );
        
        vm.makePersistent(address(proxy));
        vm.makePersistent(address(dex));
        vm.makePersistent(address(pool));
        vm.makePersistent(address(concero));
        vm.makePersistent(address(orch));

        vm.startPrank(defaultSender);
        dex.transferOwnership(Tester);
        pool.transferOwnership(Tester);
        concero.transferOwnership(Tester);
        orch.transferOwnership(Tester);
        proxy.transferOwnership(Tester);
        vm.stopPrank();
        
        //====== Update the proxy for the correct address
        vm.prank(Tester);
        proxy.upgradeTo(address(orch));
        
        //====== Wrap the proxy as the implementation
        op = Orchestrator(address(proxy));

        //====== Set the DEXes routers
        vm.startPrank(Tester);
        op.manageRouterAddress(address(uniswapV2), 1);
        op.manageRouterAddress(address(sushiV2), 1);
        op.manageRouterAddress(address(uniswapV3), 1);
        op.manageRouterAddress(address(sushiV3), 1);
        op.manageRouterAddress(address(aerodromeRouter), 1);

        //====== Set the Messenger to be allowed to interact
        pool.setConceroMessenger(Messenger, 1);
        concero.setConceroMessenger(Messenger, 1);
        vm.stopPrank();
    }

    function helper() public {
        vm.deal(User, INITIAL_BALANCE);

        assertEq(User.balance, INITIAL_BALANCE);
        assertEq(wEth.balanceOf(User), 0);

        vm.prank(User);
        wEth.deposit{value: INITIAL_BALANCE}();

        assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
    }

    function test_CanSelectFork() public {
        // select the fork
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

    }

    //Moved the logic to setUp to ease the tests
    // function test_canUpgradeTheImplementation() public {
    //     vm.startPrank(Tester);
    //     assertEq(proxy.implementation(), address(orchEmpty));

    //     proxy.upgradeTo(address(orch));

    //     assertEq(proxy.implementation(), address(orch));
    //     vm.stopPrank();
    // }

    //OK - Working
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

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
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
        assertEq(wEth.balanceOf(address(op)), 0);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOutMin);
    }

    ///_swapSushiV3Single///
    //OK - Working
    function test_swapSushiV3SingleMock() public {
        helper();
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;
        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
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
        assertEq(wEth.balanceOf(address(op)), 0);
        assertTrue(mUSDC.balanceOf(address(User))> USDC_INITIAL_BALANCE + amountOut);
    }

    ///_swapUniV3Single///
    //OK - Working
    function test_swapUniV3SingleMock() public {
        helper();
        assertEq(wEth.balanceOf(address(dex)), 0);
        
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        IDexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, 500, User, 0)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 0);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    ///_swapSushiV3Multi///
    //OK - Working
    function test_swapSushiV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 1*10**16;

        bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
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
        assertEq(wEth.balanceOf(address(op)), 0);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);
    }

    ///_swapUniV3Multi///
    //OK - Working
    function test_swapUniV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path, address(User))
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
    
        op.swap(swapData);

        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 0);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);
    }

    ///_swapDrome///
    //OK - Working
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

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
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
        assertEq(wEth.balanceOf(address(op)), 0);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    //_swapEtherOnUniV2Like//
    //Ok - Working
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
        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
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
}