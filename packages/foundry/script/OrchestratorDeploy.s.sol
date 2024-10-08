// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Orchestrator} from "contracts/Orchestrator.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";

contract OrchestratorDeploy is Script {
    function run(
        address _router,
        address _dexSwap,
        address _concero,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    ) public returns (Orchestrator orch) {
        vm.startBroadcast();
        orch = new Orchestrator(
            _router,
            _dexSwap,
            _concero,
            _pool,
            _proxy,
            _chainIndex,
            _messengers
        );
        vm.stopBroadcast();
    }
}
