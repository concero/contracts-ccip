// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {LPToken} from "contracts/LPToken.sol";

contract LPTokenDeploy is Script {
    
    function run(address _defaultAdmin, address _minter) public returns(LPToken lp){
        vm.startBroadcast();
        lp = new LPToken(_defaultAdmin, _minter);
        vm.stopBroadcast();
    }
}
