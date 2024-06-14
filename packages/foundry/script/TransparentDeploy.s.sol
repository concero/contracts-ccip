// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {ConceroProxy} from "contracts/ConceroProxy.sol";

contract TransparentDeploy is Script {

    function run(
        address _logic,
        address _admin,
        bytes memory _data
    ) public returns(ConceroProxy proxy){

        vm.startBroadcast();
        proxy = new ConceroProxy(
            _logic,
            _admin,
            _data
        );
        vm.stopBroadcast();
    }
}
