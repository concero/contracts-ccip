// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";

contract ChildPoolDeploy is Script {

    
    function run(
        address _proxy,
        address _link,
        address _ccipRouter,
        address _usdc, 
        address _orchestrator,
        address _owner
    ) public returns(ConceroChildPool child){
        vm.startBroadcast();
        child = new ConceroChildPool(_proxy, _link, _ccipRouter, _usdc, _orchestrator, _owner);
        vm.stopBroadcast();
    }
}
