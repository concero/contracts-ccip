// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {InfraProxy} from "contracts/Proxy/InfraProxy.sol";

contract InfraProxyDeploy is Script {

    function run(
        address _logic,
        address _admin,
        address _proxyOwner,
        bytes memory _data
    ) public returns(InfraProxy proxy){

        vm.startBroadcast();
        proxy = new InfraProxy(
            _logic,
            _admin,
            _proxyOwner,
            _data
        );
        vm.stopBroadcast();
    }
}
