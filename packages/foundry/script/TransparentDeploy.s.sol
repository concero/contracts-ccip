// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "../src/TransparentUpgradeableProxy.sol";

contract TransparentDeploy is Script {
    
    function run(
        address _logic, 
        address _admin, 
        bytes memory _data
    ) public returns(TransparentUpgradeableProxy proxy){

        vm.startBroadcast();
        proxy = new TransparentUpgradeableProxy(
            _logic, 
            _admin, 
            _data
        );
        vm.stopBroadcast();
    }
}