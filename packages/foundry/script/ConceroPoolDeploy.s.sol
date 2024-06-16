// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroPool} from "contracts/ConceroPool.sol";

contract ConceroPoolDeploy is Script {

    
    function run(
        address _link,
        address _ccipRouter,
        address _usdc, 
        address _lpToken, 
        address _automation
    ) public returns(ConceroPool pool){
        vm.startBroadcast();
        pool = new ConceroPool(_link, _ccipRouter, _usdc, _lpToken, _automation);
        vm.stopBroadcast();
    }
}
