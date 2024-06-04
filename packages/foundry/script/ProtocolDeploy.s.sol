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
            Concero.PriceFeeds memory _priceFeeds,
            Concero.JsCodeHashSum memory jsCodeHashSum,
            address _messenger
        ) public returns(DexSwap dex, ConceroPool pool, Concero concero, Orchestrator orch){

        vm.startBroadcast();
            dex = new DexSwap ();
            pool = new ConceroPool(_link, _ccipRouter);
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
                _priceFeeds,
                jsCodeHashSum,
                address(dex),
                address(pool)
            );
            orch = new Orchestrator(
                _functionsRouter,
                _messenger,
                address(dex),
                address(concero),
                address(pool)
            );

        vm.stopBroadcast();
    }
}