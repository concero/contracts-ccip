// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console} from "../BaseTest.t.sol";

contract FunctionsFeesTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    /// cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "s_lastGasPrices(uint64)(uint256)" 6433500567565415381 --rpc-url https://mainnet.base.org
    /// base 15971525489660198786 | 2037397 [2.037e6]
    /// polygon 4051577828743386545 | 1381749 [1.381e6]
    /// avalanche 6433500567565415381 | 25203 [2.52e4]
    /// arbitrum 4949039107694359620 | 10000000 [1e7]
    // didnt even need to hardcode the s_lastGasPrices in the end

    /// cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "s_latestLinkNativeRate()(uint256)" --rpc-url https://mainnet.base.org
    /// s_latestLinkNativeRate 4490614933160122

    /// cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "clfPremiumFees(uint64)(uint256)" 6433500567565415381 --rpc-url https://mainnet.base.org
    /// base 60000000000000000
    /// polygon 33131965864723535
    /// avalanche 240000000000000000 [2.4e17]

    /*//////////////////////////////////////////////////////////////
                       GET FUNCTIONS FEE IN LINK
    //////////////////////////////////////////////////////////////*/
    function test_getFunctionsFeeInLink() public {
        uint256 fee = baseBridgeImplementation.getFunctionsFeeInLink(arbitrumChainSelector);

        console.log("fee:", fee);
        assertGt(fee, 0);
        // 2.828327762268260022
    }

    /// Original Formula
    /// polygonFee: 93131982684225291
    /// avalancheFee: 300000003312262081

    /// CLF Formula
    /// polygonFee: 2828327762268260022
    /// avalancheFee: 2828327762268260022

    // 93131982684225291
    // 2828327762268260022

    // 300000003312262081
    // 2828327762268260022

    // doing cast call to get s_lastGasPrices for src and dst chains
    // cast call to get s_latestLinkNativeRate
    // and finally cast call to get clfPremiumFees for src and dst chains
    // hardcode these values into the old formula and get
    // 93131982684225291
    // 2828327762268260022
}
