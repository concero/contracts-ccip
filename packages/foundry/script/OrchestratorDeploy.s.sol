// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Orchestrator} from "contracts/Orchestrator.sol";

contract OrchestratorDeploy is Script {

    function run(
            address _functionsRouter,
            address _dex,
            address _concero,
            address _pool,
            address _proxy,
            uint8 _chainIndex,
            uint64 _chainSelector
    ) public returns(Orchestrator orch){

        vm.startBroadcast();
        orch = new Orchestrator(
            _functionsRouter,
            _dex,
            _concero,
            _pool,
            _proxy,
            _chainIndex,
            _chainSelector
        );
        vm.stopBroadcast();
    }
}
