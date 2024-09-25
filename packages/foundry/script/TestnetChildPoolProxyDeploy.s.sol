// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";

contract TestnetChildPoolProxyDeploy is Script {
    address _logic = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
    address _admin = 0xB015a6318f1D19DC3E135C8cEBa4bda00845c9Be;
    address _storageOwner = 0x5FA769922a6428758fb44453815e2c436c57C3c7;
    bytes _data = "";

    function run() public returns (TransparentUpgradeableProxy proxy) {
        vm.startBroadcast();
        proxy = new TransparentUpgradeableProxy(_logic, _admin, _data);
        vm.stopBroadcast();
    }
}
