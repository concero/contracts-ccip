// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";

contract TestnetParentPoolProxyDeploy is Script {
    
    address _logic = 0xE4A387A3749824FF27C7A35a70D779917Be3DBFb;
    address _admin = 0xB015a6318f1D19DC3E135C8cEBa4bda00845c9Be;
    address _storageOwner = 0x5FA769922a6428758fb44453815e2c436c57C3c7;
    bytes _data = "";

    function run() public returns(ParentPoolProxy proxy){

        vm.startBroadcast();
        proxy = new ParentPoolProxy(
            _logic,
            _admin,
            _storageOwner,
            _data
        );
        vm.stopBroadcast();
    }
}
