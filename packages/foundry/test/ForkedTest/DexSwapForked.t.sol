// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.19;

// import {Test, console} from "forge-std/Test.sol";
// import {DexSwap} from "../../src/DexSwap.sol";
// import {IDexSwap} from "../../src/Interfaces/IDexSwap.sol";
// import {Concero} from "../../src/Concero.sol";
// import {ConceroFunctions} from "../../src/ConceroFunctions.sol";

// import {DexSwapScript} from "../../script/DexSwapScript.s.sol";
// import {ConceroDeploy} from "../../script/ConceroDeploy.s.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

// import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
// import {IRouter} from "@velodrome/contracts/interfaces/IRouter.sol";
// import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
// import {ISwapRouter02, IV3SwapRouter} from "../../src/Interfaces/ISwapRouter02.sol";

// interface IWETH is IERC20 {
//     function deposit() external payable;

//     function withdraw(uint256) external;
// }

// contract DexSwapTest is Test {
//     DexSwapScript public deploy;
//     DexSwap public dex;
//     Concero public concero;
//     ConceroDeploy public deployConcero;

//     IWETH wEth;
//     IERC20 USDC;
//     ERC20Mock AERO;

//     IUniswapV2Router02 uniswapV2;
//     IUniswapV2Router02 sushiV2;
//     ISwapRouter02 uniswapV3;
//     ISwapRouter sushiV3;
//     IRouter aerodromeRouter;

//     ERC20Mock tUSDC;

//     address User = makeAddr("User");
//     address Barba = makeAddr("Barba");
//     address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

//     uint256 private baseMainFork;
//     string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
//     uint256 private constant INITIAL_BALANCE = 10 ether;

//     function setUp() public {
//         baseMainFork = vm.createFork(BASE_RPC_URL);
//         vm.selectFork(baseMainFork);

//         uniswapV2 = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
//         sushiV2 = IUniswapV2Router02(0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891);
//         uniswapV3 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
//         sushiV3 = ISwapRouter(0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f);
//         aerodromeRouter = IRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);


//         wEth = IWETH(0x4200000000000000000000000000000000000006);
//         USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
//         AERO = ERC20Mock(0x940181a94A35A4569E4529A3CDfB74e38FD98631);

//         deploy = new DexSwapScript();
//         deployConcero = new ConceroDeploy();

//         dex = deploy.run();
//         vm.makePersistent(address(dex));

//         concero = deployConcero.run(
//             0xf9B8fc078197181C841c296C876945aaa425B278, //address _functionsRouter
//             0, //uint64 _donHostedSecretsVersion
//             0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000, //bytes32 _donId
//             2, //uint8 _donHostedSecretsSlotId
//             0, //uint64 _subscriptionId,
//             15971525489660198786, //uint64 _chainSelector,
//             1, //uint _chainIndex,
//             0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196, //address _link,
//             0x881e3A65B4d4a04dD529061dd0071cf975F58bCD, //address _ccipRouter,
//             address(dex),
//             Concero.PriceFeeds ({
//                 linkToUsdPriceFeeds: 0x17CAb8FE31E32f08326e5E27412894e49B0f9D65,
//                 usdcToUsdPriceFeeds: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
//                 nativeToUsdPriceFeeds: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
//                 linkToNativePriceFeeds: 0xc5E65227fe3385B88468F9A01600017cDC9F3A12
//             }),
//             ConceroFunctions.JsCodeHashSum ({
//                 src: 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124,
//                 dst: 0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173
//             })
//         );
        
//         vm.makePersistent(address(concero));

//         vm.startPrank(defaultSender);
//         dex.transferOwnership(Barba);
//         concero.transferOwnership(Barba);
//         vm.stopPrank();

//         vm.startPrank(Barba);
//         concero.acceptOwnership();
//         dex.manageOrchestratorContract(address(concero));
//         dex.manageRouterAddress(address(uniswapV2), 1);
//         dex.manageRouterAddress(address(sushiV2), 1);
//         dex.manageRouterAddress(address(uniswapV3), 1);
//         dex.manageRouterAddress(address(sushiV3), 1);
//         dex.manageRouterAddress(address(aerodromeRouter), 1);

//         //Only to test dustCollector
//         tUSDC = new ERC20Mock("Teste USDC", "tUSDC", Barba, INITIAL_BALANCE);
//         tUSDC.mint(address(dex), INITIAL_BALANCE);
//         vm.stopPrank();
//     }

//     function helper() public {
//         vm.deal(User, INITIAL_BALANCE);

//         assertEq(User.balance, INITIAL_BALANCE);
//         assertEq(wEth.balanceOf(User), 0);

//         vm.prank(User);
//         wEth.deposit{value: INITIAL_BALANCE}();

//         assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
//     }

//     function test_CanSelectFork() public {
//         // select the fork
//         vm.selectFork(baseMainFork);
//         assertEq(vm.activeFork(), baseMainFork);

//     }

//     ///manageOrchestratorContract///
//     event DexSwap_OrchestratorContractUpdated(address previousAddress, address User);
//     function test_manageUser() public {
//         vm.prank(Barba);
//         vm.expectEmit();
//         emit DexSwap_OrchestratorContractUpdated(address(concero), address(concero));
//         dex.manageOrchestratorContract(address(concero));
//     }

//     ///manageRouterAddress////
//     event DexSwap_NewRouterAdded(address router, uint256 isAllowed);
//     function test_manageRouterAddress() public {
//         vm.prank(Barba);
//         vm.expectEmit();
//         emit DexSwap_NewRouterAdded(0x425141165d3DE9FEC831896C016617a52363b687, 1);
//         dex.manageRouterAddress(0x425141165d3DE9FEC831896C016617a52363b687, 1);
//     }

//     ///dustRemoval///
//     event DexSwap_RemovingDust(address caller, uint256 amount);
//     function test_dustRemoval() public {
//         vm.prank(Barba);
//         vm.expectEmit();
//         emit DexSwap_RemovingDust(Barba, INITIAL_BALANCE);
//         dex.dustRemoval(address(tUSDC), INITIAL_BALANCE);
//     }

//     ///conceroEntry///
//     function test_swapUniV2LikeForked() public {
//         //==== Getting balance on the forked testnet
//         helper();

//         //==== Mock the payload
//         uint amountIn = 0.1 ether;
//         uint amountOutMin = 270*10**6;
//         address[] memory path = new address[](2);
//         path[0] = address(wEth);
//         path[1] = address(USDC);
//         address to = address(User);
//         uint deadline = block.timestamp + 1800;

//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//                             dexType: IDexSwap.DexType.UniswapV2,
//                             fromToken: address(wEth),
//                             fromAmount: amountIn,
//                             toToken: address(USDC),
//                             toAmount: amountOutMin,
//                             toAmountMin: amountOutMin,
//                             dexData: abi.encode(sushiV2, path, to, deadline)
//                         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), 0.1 ether);

//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertEq(wEth.balanceOf(address(User)), 9.9 ether);
//         assertEq(wEth.balanceOf(address(dex)), 0);
//         assertTrue(USDC.balanceOf(address(User)) > 270*10**6);
//     }

//     ///_swapSushiV3Single///
//     ///OK
//     function test_swapSushiV3SingleForked() public {
//         //==== Getting balance on the forked testnet
//         helper();

//         //==== Mock the payload
//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//                             dexType: IDexSwap.DexType.SushiV3Single,
//                             fromToken: address(wEth),
//                             fromAmount: 1*10**17,
//                             toToken: address(USDC),
//                             toAmount: 120*10**6,
//                             toAmountMin: 120*10**6,
//                             dexData: abi.encode(sushiV3, 500, address(User), block.timestamp + 1800, 0)
//                         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), 1 ether);

//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertEq(wEth.balanceOf(address(User)), 9.9 ether);
//         assertEq(wEth.balanceOf(address(dex)), 0);
//         assertTrue(USDC.balanceOf(address(User)) > 120*10**6);
//     }

//     ///_swapUniV3Single///
//     ///OK
//     function test_swapUniV3SingleForked() public {
//         //==== Getting balance on the forked testnet
//         helper();

//         //==== Mock the payload
//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.UniswapV3Single,
//             fromToken: address(wEth),
//             fromAmount: 1*10**17,
//             toToken: address(USDC),
//             toAmount: 260*10**6,
//             toAmountMin: 260*10**6,
//             dexData: abi.encode(uniswapV3, 500, address(User), 0)
//         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), 1*10**17);
    
//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertEq(wEth.balanceOf(address(User)), 9.9 ether);
//         assertEq(wEth.balanceOf(address(dex)), 0);
//         assertTrue(USDC.balanceOf(address(User)) > 260*10**6);
//     }

//     ///_swapSushiV3Multi///
//     function test_swapSushiV3MultiForked() public {
//         //==== Getting balance on the forked testnet
//         helper();

//         //==== Mock the payload
//         uint24 poolFee = 500;
//         bytes memory path = abi.encodePacked(wEth, poolFee, USDC, poolFee, wEth);
//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.SushiV3Multi,
//             fromToken: address(wEth),
//             fromAmount: 1*10**17,
//             toToken: address(USDC),
//             toAmount: 9*10**16,
//             toAmountMin: 9*10**16,
//             dexData: abi.encode(sushiV3, path, address(User), block.timestamp + 300)
//         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), 1*10**17);

//         assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
//         assertEq(wEth.allowance(User, address(concero)), 1*10**17);
    
//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertTrue(wEth.balanceOf(User) > (INITIAL_BALANCE - 1*10**17 + 9*10**16));
//     }

//     ///_swapUniV3Multi///
//     function test_swapUniV3MultiForked() public {
//         //==== Getting balance on the forked testnet
//         helper();

//         //==== Mock the payload
//         uint24 poolFee = 500;
//         bytes memory path = abi.encodePacked(wEth, poolFee, USDC, poolFee, wEth);
//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.UniswapV3Multi,
//             fromToken: address(wEth),
//             fromAmount: 1*10**17,
//             toToken: address(USDC),
//             toAmount: 9*10**16,
//             toAmountMin: 9*10**16,
//             dexData: abi.encode(uniswapV3, path, address(User))
//         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), 1*10**17);

//         assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
//         assertEq(wEth.allowance(User, address(concero)), 0.1 ether);
    
//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertTrue(wEth.balanceOf(User) > 0.09 ether);
//     }

//     ///_swapDrome///
//     ///OK
//     function test_swapDromeForked() public {
//         vm.selectFork(baseMainFork);

//         //==== Getting balance on the forked testnet
//         vm.deal(User, INITIAL_BALANCE);
//         assertEq(User.balance, INITIAL_BALANCE);
//         assertEq(wEth.balanceOf(User), 0);
//         vm.prank(User);
//         wEth.deposit{value: INITIAL_BALANCE}();
//         assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
        
//         //==== Mock the payload
//         IRouter.Route[] memory route = new IRouter.Route[](1);

//         IRouter.Route memory routes = IRouter.Route({
//             from: address(wEth),
//             to: address(AERO),
//             stable: false,
//             factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
//         });

//         route[0] = routes;

//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.Aerodrome,
//             fromToken: address(wEth),
//             fromAmount: 9*10**17,
//             toToken: address(USDC),
//             toAmount: 280*10**6,
//             toAmountMin: 280*10**6,
//             dexData: abi.encode(aerodromeRouter, route, Barba, block.timestamp + 1800)
//         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), 1 ether);
    
//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertEq(wEth.balanceOf(address(dex)), 0);
//         assertTrue(AERO.balanceOf(Barba) > 280 ether );
//     }

//     //multiple swaps in different DEXes
//     function test_swapInDifferentDEXesForked() public {
//         vm.selectFork(baseMainFork);

//         //==== Getting balance on the forked testnet
//         vm.deal(User, INITIAL_BALANCE);
//         assertEq(User.balance, INITIAL_BALANCE);
//         assertEq(wEth.balanceOf(User), 0);
//         vm.prank(User);
//         wEth.deposit{value: INITIAL_BALANCE}();
//         assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

//         //======= Aerodrome
//         //==== Mock the payload
//         IRouter.Route[] memory route = new IRouter.Route[](1);
//         IRouter.Route memory routes = IRouter.Route({
//             from: address(wEth),
//             to: address(USDC),
//             stable: false,
//             factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
//         });
//         route[0] = routes;

//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](2);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.Aerodrome,
//             fromToken: address(wEth),
//             fromAmount: 0.1 ether,
//             toToken: address(USDC),
//             toAmount: 350*10**6,
//             toAmountMin: 350*10**6,
//             dexData: abi.encode(aerodromeRouter, route, dex, block.timestamp + 1800)
//         });

//         //==== Approve Transfer
//         vm.startPrank(User);
//         wEth.approve(address(concero), INITIAL_BALANCE);

//         //======== Uniswap V3 Multi
//         //==== Mock the payload        
//         uint24 poolFee = 500;
//         bytes memory path = abi.encodePacked(USDC, poolFee, wEth);
//         swapData[1] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.UniswapV3Multi,
//             fromToken: address(USDC),
//             fromAmount: 350*10**6,
//             toToken: address(wEth),
//             toAmount: 8*10**16,
//             toAmountMin: 8*10**16,
//             dexData: abi.encode(uniswapV3, path, User)
//         });
    
//         //==== Initiate transaction
//         concero.swap(swapData);

//         //==== Check results
//         assertEq(wEth.balanceOf(address(concero)), 0);
//         assertTrue(wEth.balanceOf(User) > (INITIAL_BALANCE - 1*10**17 + 9*10**16));
//     }

//     //_swapEtherOnUniV2Like//
//     function test_swapEtherOnUniV2LikeForked() public {
//         //===== Mock the value.
//                 //In this case, the value is passed as a param through the function
//                 //Also is transferred in the call
//         uint256 amountToSend = 0.1 ether;

//         //===== Mock the data for payload to send to the function
//         uint amountOutMin = 350*10**6;
//         address[] memory path = new address[](2);
//         path[0] = address(wEth);
//         path[1] = address(USDC);
//         address to = address(User);
//         uint deadline = block.timestamp + 1800;

//         //===== Gives User some ether and checks the balance
//         vm.deal(User, INITIAL_BALANCE);
//         assertEq(User.balance, INITIAL_BALANCE);

//         //===== Mock the payload to send on the function
//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.UniswapV2Ether,
//             fromToken: address(0),
//             fromAmount: amountToSend,
//             toToken: address(USDC),
//             toAmount: amountOutMin,
//             toAmountMin: amountOutMin,
//             dexData: abi.encode(uniswapV2, path, to, deadline)
//         });

//         //===== Start transaction calling the function and passing the payload
//         vm.startPrank(User);                    
//         concero.swap{value: amountToSend}(swapData);
//         vm.stopPrank();

//         assertEq(User.balance, 9.9 ether);
//         assertTrue(USDC.balanceOf(address(User)) > 350*10**6);
//     }
// }