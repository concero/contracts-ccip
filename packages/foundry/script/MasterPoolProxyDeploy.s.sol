// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MasterPoolProxy} from "contracts/Proxy/MasterPoolProxy.sol";

contract MasterPoolProxyDeploy is Script {

    function run(
        address _logic,
        address _admin,
        address _storageOwner,
        bytes memory _data
    ) public returns(MasterPoolProxy proxy){

        vm.startBroadcast();
        proxy = new MasterPoolProxy(
            _logic,
            _admin,
            _storageOwner,
            _data
        );
        vm.stopBroadcast();
    }
}
