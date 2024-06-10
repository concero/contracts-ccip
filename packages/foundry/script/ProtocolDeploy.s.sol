// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DexSwap} from "../src/DexSwap.sol";
import {ConceroPool} from "../src/ConceroPool.sol";
import {Concero} from "../src/Concero.sol";
import {Orchestrator} from "../src/Orchestrator.sol";

contract ProtocolDeploy is Script {
    function run(
            address _functionsRouter,
            uint64 _donHostedSecretsVersion,
            bytes32 _donId,
            uint8 _donHostedSecretsSlotId,
            uint64 _subscriptionId,
            uint64 _chainSelector,
            uint _chainIndex,
            address _link,
            address _ccipRouter,
            Concero.JsCodeHashSum memory jsCodeHashSum,
            bytes32 _ethersHashSum,
            address _messenger,
            address _proxy
        ) public returns(DexSwap dex, ConceroPool pool, Concero concero, Orchestrator orch){

        vm.startBroadcast();
            dex = new DexSwap (_proxy);
            pool = new ConceroPool(_link, _ccipRouter, _proxy);
            concero = new Concero(
                _functionsRouter,
                _donHostedSecretsVersion,
                _donId,
                _donHostedSecretsSlotId,
                _subscriptionId,
                _chainSelector,
                _chainIndex,
                _link,
                _ccipRouter,
                jsCodeHashSum,
                _ethersHashSum,
                address(dex),
                address(pool),
                _proxy
            );
            orch = new Orchestrator(
                _functionsRouter,
                address(dex),
                address(concero),
                address(pool),
                _proxy
            );

        vm.stopBroadcast();
    }
}