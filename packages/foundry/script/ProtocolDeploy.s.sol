// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DexSwap} from "contracts/DexSwap.sol";
import {ConceroPool} from "contracts/ConceroPool.sol";
import {Concero} from "contracts/Concero.sol";
import {Orchestrator} from "contracts/Orchestrator.sol";
import {Storage} from "contracts/Libraries/Storage.sol";

contract ProtocolDeploy is Script {
    function run(
            Storage.FunctionsVariables memory _variables,
            uint64 _chainSelector,
            uint _chainIndex,
            address _link,
            address _ccipRouter,
            Concero.JsCodeHashSum memory jsCodeHashSum,
            bytes32 _ethersHashSum,
            address _proxy,
            address _usdc
        ) public returns(DexSwap dex, ConceroPool pool, Concero concero, Orchestrator orch){

        vm.startBroadcast();
            dex = new DexSwap (_proxy);
            pool = new ConceroPool(_link, _ccipRouter, _proxy, _usdc);
            concero = new Concero(
                _variables,
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
                _variables.functionsRouter,
                address(dex),
                address(concero),
                address(pool),
                _proxy
            );

        vm.stopBroadcast();
    }
}
