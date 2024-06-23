// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";

contract ParentPoolProxyDeploy is Script {

    function run(
        address _logic,
        address _admin,
        address _storageOwner,
        bytes memory _data
    ) public returns(ParentPoolProxy proxy){

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
