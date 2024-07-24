// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {Test, console2} from "forge-std/Test.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
// import {Concero} from "contracts/Concero.sol";
// import {IConceroCommon, IFunctions} from "contracts/IConceroBridge.sol";
// import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

// string constant BASE_SEPOLIA_RPC = "https://sepolia.base.org";
// uint256 constant BASE_SEPOLIA_END_FORK_BLOCK_NUMBER = 10171514;

// contract ConceroGasAbstractionTest is Test {
//     ConceroMock public concero;
//     uint256 public baseForkId;

//     function setUp() public {
//         baseForkId = vm.createFork(BASE_SEPOLIA_RPC, BASE_SEPOLIA_END_FORK_BLOCK_NUMBER);
//         vm.selectFork(baseForkId);

//         concero = new ConceroMock(
//             0xf9B8fc078197181C841c296C876945aaa425B278,
//             1715958404,
//             0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000,
//             0,
//             16,
//             10344971235874465080,
//             1,
//             0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
//             0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93,
//             0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93,
//             IFunctions.JsCodeHashSum({src: 0x0, dst: 0x0})
//         );

//         concero.setLastGasPrices(5224473277236331295, 1000263);
//         concero.setLastGasPrices(10344971235874465080, 1000292);
//     }

//     function test_getDstTotalFeeInUsdc() public view {
//         uint256 dstFee = concero.getDstTotalFeeInUsdc(10 ether);
//         assert(dstFee == 0.01 ether);
//     }

//     function test_getCCIIPFeeInUsdc() public view {
//         uint256 ccipFee = concero.getCCIPFeeInUsdc(IConceroCommon.CCIPToken.bnm, 5224473277236331295);
//         assert(ccipFee == 0.170980663044073040 ether);
//     }

//     function test_getFunctionsFeeInUsdc() public view {
//         uint256 functionsFee = concero.getFunctionsFeeInUsdc(5224473277236331295);
//         assert(functionsFee == 0.063584862174435019 ether);
//     }

//     function test_getSrcFee() public view {
//         uint256 totalFee = concero.getSrcTotalFeeInUsdc(IConceroCommon.CCIPToken.bnm, 5224473277236331295, 1000000000000000000);
//         assert(totalFee == 0.240220524283293254 ether);
//     }
// }

// contract ConceroMock is Concero {
//     constructor(
//         address _functionsRouter,
//         uint64 _donHostedSecretsVersion,
//         bytes32 _donId,
//         uint8 _donHostedSecretsSlotId,
//         uint64 _subscriptionId,
//         uint64 _chainSelector,
//         uint _chainIndex,
//         address _link,
//         address _ccipRouter,
//         address _dexSwap,
//         JsCodeHashSum memory jsCodeHashSum
//     )
//     Concero(
//     _functionsRouter,
//     _donHostedSecretsVersion,
//     _donId,
//     _donHostedSecretsSlotId,
//     _subscriptionId,
//     _chainSelector,
//     _chainIndex,
//     _link,
//     _ccipRouter,
//     _dexSwap,
//     jsCodeHashSum
//     )
//     {}

//     function setLastGasPrices(uint64 _token, uint256 _price) public {
//         s_lastGasPrices[_token] = _price;
//     }

//     function setLastPriceFeeds() public {
//         s_latestLinkUsdcRate = 0;
// 		s_latestLinkNativeRate = 0;
//         s_latestNativeUsdcRate = 0;
//     }
// }
