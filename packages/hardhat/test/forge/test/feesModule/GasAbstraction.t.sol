// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Concero} from "contracts/Concero.sol";
import {IConceroCommon} from "contracts/IConcero.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

string constant BASE_SEPOLIA_RPC = "https://sepolia.base.org";
uint256 constant BASE_SEPOLIA_END_FORK_BLOCK_NUMBER = 10171514;

contract ConceroGasAbstractionTest is Test {
  Concero public concero;
  uint256 public baseForkId;

  function setUp() public {
    baseForkId = vm.createFork(BASE_SEPOLIA_RPC, BASE_SEPOLIA_END_FORK_BLOCK_NUMBER);
    vm.selectFork(baseForkId);

    concero = new Concero(
      0xf9B8fc078197181C841c296C876945aaa425B278,
      1715958404,
      0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000,
      0,
      16,
      10344971235874465080,
      1,
      0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
      0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93,
      Concero.PriceFeeds({
        linkToUsdPriceFeeds: 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61,
        usdcToUsdPriceFeeds: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165,
        nativeToUsdPriceFeeds: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1,
        linkToNativePriceFeeds: 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69
      })
    );
  }

  function test_getTotalFee() public view {
    uint256 ccipFee = concero.getCCIPFeeInUsdc(IConceroCommon.CCIPToken.bnm, 5224473277236331295);
    console2.logUint(ccipFee);

    uint256 totalFee = concero.getSrcTotalFeeInUsdc(IConceroCommon.CCIPToken.bnm, 5224473277236331295, 1000000000000000000);
    console2.logUint(totalFee);
  }
}
