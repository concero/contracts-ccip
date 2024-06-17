// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";

contract AutomationDeploy is Script {
    
    function run(address _functions, address _owner) public returns(ConceroAutomation automation){
        vm.startBroadcast();
        automation = new ConceroAutomation(_functions, _owner);
        vm.stopBroadcast();
    }
}
