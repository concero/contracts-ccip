// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";

contract ParentPoolProxyDeploy is Script {
    function run(
        address _logic,
        address _admin,
        bytes memory _data
    ) public returns (ParentPoolProxy proxy) {
        vm.startBroadcast(vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY"));
        proxy = new ParentPoolProxy(_logic, _admin, _data);

        vm.stopBroadcast();
    }
}
