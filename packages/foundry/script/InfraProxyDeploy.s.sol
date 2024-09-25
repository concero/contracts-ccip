// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";

contract InfraProxyDeploy is Script {
    function run(
        address _logic,
        address _admin,
        bytes memory _data
    ) public returns (TransparentUpgradeableProxy proxy) {
        vm.startBroadcast();
        proxy = new TransparentUpgradeableProxy(_logic, _admin, _data);
        vm.stopBroadcast();
    }
}
