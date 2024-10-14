// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
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
    ) public returns (InfraOrchestrator orch) {
        vm.startBroadcast();
        orch = new InfraOrchestrator(
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
