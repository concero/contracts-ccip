// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.20;

// import {Test, console} from "forge-std/Test.sol";

// import {Concero} from "contracts/Concero.sol";
// import {ConceroFunctions} from "contracts/ConceroFunctions.sol";
// import {DexSwap} from "contracts/DexSwap.sol";
// import {InfraProxy} from "contracts/Proxy/InfraProxy.sol";

// import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";

// import {ConceroMock} from "../Mocks/ConceroMock.sol";

// import {ConceroMockDeploy} from "../../script/ConceroMockDeploy.s.sol";
// import {DexSwapDeploy} from "../../script/DexSwapDeploy.s.sol";
// import {InfraProxyDeploy} from "../../script/InfraProxyDeploy.s.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
// import {DEXMock} from "../Mocks/DEXMock.sol";
// import {DEXMock2} from "../Mocks/DEXMock2.sol";
// import {USDC} from "../Mocks/USDC.sol";

// import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
// import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
// import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
// import {ISwapRouter02, IV3SwapRouter} from "contracts/Interfaces/ISwapRouter02.sol";

// contract DexSwapTest is Test {
//     DexSwap public dex;
//     ConceroMock public concero;

//     DexSwapDeploy public deploy;
//     ConceroMockDeploy public deployConcero;

//     ERC20Mock wEth;
//     USDC public mUSDC;
//     ERC20Mock AERO;
//     DEXMock dexMock;
//     DEXMock2 dexMock2;

//     address User = makeAddr("User");
//     address Barba = makeAddr("Barba");
//     address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

//     uint256 private constant PT_INITIAL_BALANCE = 100 ether;
//     uint256 private constant USDC_INITIAL_BALANCE = 100 * 10**6;
//     uint256 private constant ORCH_BALANCE = 10 ether;
//     uint256 private constant ORCH_USDC_BALANCE = 10 * 10**6;

//     function setUp() public {

//         wEth = new ERC20Mock();
//         AERO = new ERC20Mock();
//         mUSDC = new USDC("USDC", "mUSDC", Barba, 2 * USDC_INITIAL_BALANCE);

//         dexMock = new DEXMock();
//         dexMock2 = new DEXMock2();

//         wEth.mint(User, ORCH_BALANCE);
//         AERO.mint(User, ORCH_BALANCE);
//         mUSDC.mint(User, ORCH_USDC_BALANCE);

//         deploy = new DexSwapDeploy();
//         deployConcero = new ConceroMockDeploy();

//         dex = deploy.run(_proxy, Tester);
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

//         vm.startPrank(defaultSender);
//         dex.transferOwnership(Barba);
//         concero.transferOwnership(Barba);
//         vm.stopPrank();

//         vm.startPrank(Barba);
//         concero.acceptOwnership();
//         dex.manageOrchestratorContract(address(concero));
//         dex.manageRouterAddress(address(dexMock), 1);
//         dex.manageRouterAddress(address(dexMock2), 1);
//         vm.stopPrank();
//     }

//     function helper() public {
//         vm.startPrank(Barba);
//         //======== DexSwap Mock
//         wEth.approve(address(dexMock), PT_INITIAL_BALANCE);
//         AERO.approve(address(dexMock), PT_INITIAL_BALANCE);
//         mUSDC.approve(address(dexMock), USDC_INITIAL_BALANCE);
//         dexMock.depositToken(address(wEth), PT_INITIAL_BALANCE);
//         dexMock.depositToken(address(AERO), PT_INITIAL_BALANCE);
//         dexMock.depositToken(address(mUSDC), USDC_INITIAL_BALANCE);
//         //======== DexSwap Mock2
//         wEth.approve(address(dexMock2), PT_INITIAL_BALANCE);
//         AERO.approve(address(dexMock2), PT_INITIAL_BALANCE);
//         mUSDC.approve(address(dexMock2), USDC_INITIAL_BALANCE);
//         dexMock2.depositToken(address(wEth), PT_INITIAL_BALANCE);
//         dexMock2.depositToken(address(AERO), PT_INITIAL_BALANCE);
//         dexMock2.depositToken(address(mUSDC), USDC_INITIAL_BALANCE);
//         vm.stopPrank();
//         assertEq(wEth.balanceOf(address(dexMock)), PT_INITIAL_BALANCE);
//         assertEq(AERO.balanceOf(address(dexMock)), PT_INITIAL_BALANCE);
//         assertEq(mUSDC.balanceOf(address(dexMock)), USDC_INITIAL_BALANCE);
//         assertEq(wEth.balanceOf(address(dexMock2)), PT_INITIAL_BALANCE);
//         assertEq(AERO.balanceOf(address(dexMock2)), PT_INITIAL_BALANCE);
//         assertEq(mUSDC.balanceOf(address(dexMock2)), USDC_INITIAL_BALANCE);
//     }

//     //OK - Working
//     function test_swapUniV2LikeMock() public {
//         helper();

//         uint amountIn = 1*10**17;
//         uint amountOutMin = 1*10**5;
//         address[] memory path = new address[](2);
//         path[0] = address(wEth);
//         path[1] = address(mUSDC);
//         address to = User;
//         uint deadline = block.timestamp + 1800;

//         vm.startPrank(User);
//         wEth.approve(address(concero), amountIn);

//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//                             dexType: IDexSwap.DexType.UniswapV2,
//                             fromToken: address(wEth),
//                             fromAmount: amountIn,
//                             toToken: address(mUSDC),
//                             toAmount: amountOutMin,
//                             toAmountMin: amountOutMin,
//                             dexData: abi.encode(dexMock, path, to, deadline)
//                         });

//         concero.swap(swapData);

//         assertEq(wEth.balanceOf(address(User)), ORCH_BALANCE - amountIn);
//         assertEq(wEth.balanceOf(address(dex)), 0);
//         assertEq(mUSDC.balanceOf(address(User)), ORCH_USDC_BALANCE + amountOutMin);
//     }

//     ///_swapSushiV3Single///
//     //OK - Working
//     function test_swapSushiV3SingleMock() public {
//         helper();

//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//                             dexType: IDexSwap.DexType.SushiV3Single,
//                             fromToken: address(wEth),
//                             fromAmount: 1*10**17,
//                             toToken: address(mUSDC),
//                             toAmount: 1*10**5,
//                             toAmountMin: 1*10**5,
//                             dexData: abi.encode(dexMock2, 500, address(User), block.timestamp + 1800, 0)
//                         });

//         vm.startPrank(User);
//         wEth.approve(address(concero), 1 ether);

//         concero.swap(swapData);

//         assertEq(wEth.balanceOf(address(User)), 9.9 ether);
//         assertEq(wEth.balanceOf(address(concero)), 0);
//         assertEq(mUSDC.balanceOf(address(User)), ORCH_USDC_BALANCE + 1*10**5);
//     }

//     ///_swapUniV3Single///
//     //OK - Working
//     function test_swapUniV3SingleMock() public {
//         helper();
//         assertEq(wEth.balanceOf(address(dex)), 0);

//         uint256 amountToDeposit = 1*10**17;
//         uint256 amountToReceive = 1*10**5;

//         IDexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);

//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.UniswapV3Single,
//             fromToken: address(wEth),
//             fromAmount: amountToDeposit,
//             toToken: address(mUSDC),
//             toAmount: amountToReceive,
//             toAmountMin: amountToReceive,
//             dexData: abi.encode(address(dexMock), 500, User, 0)
//         });

//         vm.startPrank(User);
//         wEth.approve(address(concero), amountToDeposit);

//         concero.swap(swapData);

//         assertEq(wEth.balanceOf(address(User)), ORCH_BALANCE - amountToDeposit);
//         assertEq(mUSDC.balanceOf(address(User)), ORCH_USDC_BALANCE + amountToReceive);
//         assertEq(wEth.balanceOf(address(dex)), 0);
//         assertEq(wEth.balanceOf(address(dexMock)), PT_INITIAL_BALANCE + amountToDeposit);
//         assertEq(mUSDC.balanceOf(address(dexMock)), USDC_INITIAL_BALANCE - amountToReceive);
//     }

//     ///_swapSushiV3Multi///
//     // function test_swapSushiV3MultiMock() public {
//     //     helper();

//     //     uint24 poolFee = 500;

//     //     bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

//     //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//     //     swapData[0] = IDexSwap.SwapData({
//     //         dexType: IDexSwap.DexType.SushiV3Multi,
//     //         fromToken: address(wEth),
//     //         fromAmount: 1*10**17,
//     //         toToken: address(mUSDC),
//     //         toAmount: 9*10**16,
//     //         toAmountMin: 9*10**16,
//     //         dexData: abi.encode(dexMock, path, address(User), block.timestamp + 300)
//     //     });

//     //     vm.startPrank(User);
//     //     wEth.approve(address(concero), 1*10**17);

//     //     assertEq(wEth.balanceOf(User), ORCH_BALANCE);
//     //     assertEq(wEth.allowance(User, address(concero)), 0.1 ether);

//     //     concero.swap(swapData);

//     //     assertTrue(wEth.balanceOf(User) > 0.09 ether);
//     // }

//     ///_swapUniV3Multi///
//     // function test_swapUniV3MultiMock() public {
//     //     helper();

//     //     uint24 poolFee = 500;

//     //     bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

//     //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//     //     swapData[0] = IDexSwap.SwapData({
//     //         dexType: IDexSwap.DexType.UniswapV3Multi,
//     //         fromToken: address(wEth),
//     //         fromAmount: 1*10**17,
//     //         toToken: address(mUSDC),
//     //         toAmount: 1*10**6,
//     //         toAmountMin: 1*10**6,
//     //         dexData: abi.encode(dexMock2, path, address(User))
//     //     });

//     //     vm.startPrank(User);
//     //     wEth.approve(address(concero), 1*10**17);

//     //     concero.swap(swapData);

//     // }

//     ///_swapDrome///
//     //OK - Working
//     function test_swapDromeMock() public {
//         helper();

//         assertEq(wEth.balanceOf(User), ORCH_BALANCE);

//         uint256 amountToDeposit = 1*10**17;
//         uint256 amountToReceive = 1*10**5;

//         IRouter.Route[] memory route = new IRouter.Route[](1);

//         IRouter.Route memory routes = IRouter.Route({
//             from: address(wEth),
//             to: address(mUSDC),
//             stable: false,
//             factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
//         });

//         route[0] = routes;

//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.Aerodrome,
//             fromToken: address(wEth),
//             fromAmount: amountToDeposit,
//             toToken: address(mUSDC),
//             toAmount: amountToReceive,
//             toAmountMin: amountToReceive,
//             dexData: abi.encode(dexMock2, route, Barba, block.timestamp + 1800)
//         });

//         vm.startPrank(User);
//         wEth.approve(address(concero), 1 ether);

//         assertEq(mUSDC.balanceOf(address(dexMock2)), USDC_INITIAL_BALANCE);

//         concero.swap(swapData);

//         assertEq(wEth.balanceOf(address(dexMock2)), PT_INITIAL_BALANCE + amountToDeposit);
//         assertEq(mUSDC.balanceOf(address(dexMock2)), USDC_INITIAL_BALANCE - amountToReceive);
//     }

//     //_swapEtherOnUniV2Like//
//     //Ok - Working
//     function test_swapEtherOnUniV2LikeMock() public {
//         helper();

//         //===== Mock the value.
//                 //In this case, the value is passed as a param through the function
//                 //Also is transferred in the call
//         uint256 amountToSend = 0.1 ether;

//         //===== Mock the data for payload to send to the function
//         uint amountOutMin = 1*10**6;
//         address[] memory path = new address[](2);
//         path[0] = address(wEth);
//         path[1] = address(mUSDC);
//         address to = address(User);
//         uint deadline = block.timestamp + 1800;

//         //===== Gives User some ether and checks the balance
//         vm.deal(User, ORCH_BALANCE);
//         assertEq(User.balance, ORCH_BALANCE);

//         //===== Mock the payload to send on the function
//         DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
//         swapData[0] = IDexSwap.SwapData({
//             dexType: IDexSwap.DexType.UniswapV2Ether,
//             fromToken: address(0),
//             fromAmount: amountToSend,
//             toToken: address(mUSDC),
//             toAmount: amountOutMin,
//             toAmountMin: amountOutMin,
//             dexData: abi.encode(dexMock, path, to, deadline)
//         });

//         //===== Start transaction calling the function and passing the payload
//         vm.startPrank(User);
//         concero.swap{value: amountToSend}(swapData);
//         vm.stopPrank();

//         assertEq(User.balance, ORCH_BALANCE - 0.1 ether);
//         assertEq(mUSDC.balanceOf(address(User)), ORCH_USDC_BALANCE + 1*10**6);
//     }
// }
