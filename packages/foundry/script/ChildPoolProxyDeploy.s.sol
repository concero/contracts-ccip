// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";

contract ChildPoolProxyDeploy is Script {

    function run(
        address _logic,
        address _admin,
        bytes memory _data
    ) public returns(ChildPoolProxy proxy){

        vm.startBroadcast();
        proxy = new ChildPoolProxy(
            _logic,
            _admin,
            _data
        );
        vm.stopBroadcast();
    }
}
