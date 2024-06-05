// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DexSwap} from "../src/DexSwap.sol";

contract DexSwapDeploy is Script {
    
    function run(address _proxy) public returns(DexSwap dexSwap){
        vm.startBroadcast();
        dexSwap = new DexSwap(_proxy);
        vm.stopBroadcast();
    }
}
