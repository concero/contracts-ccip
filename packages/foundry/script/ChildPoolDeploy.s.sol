// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";

contract ChildPoolDeploy is Script {
    function run(
        address _orchestratorProxy,
        address _childProxy,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _owner,
        address[3] memory _messengers
    ) public returns (ConceroChildPool child) {
        vm.startBroadcast();
        child = new ConceroChildPool(
            _orchestratorProxy,
            _childProxy,
            _link,
            _ccipRouter,
            _usdc,
            _owner,
            _messengers
        );
        vm.stopBroadcast();
    }
}
