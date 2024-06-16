// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";

contract ChildPoolDeploy is Script {

    
    function run(
        address _link,
        address _ccipRouter,
        address _usdc
    ) public returns(ConceroChildPool child){
        vm.startBroadcast();
        child = new ConceroChildPool(_link, _ccipRouter, _usdc);
        vm.stopBroadcast();
    }
}
