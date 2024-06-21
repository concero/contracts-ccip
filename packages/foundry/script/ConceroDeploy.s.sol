// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Concero} from "contracts/Concero.sol";
import {Storage} from "contracts/Libraries/Storage.sol";

contract ConceroDeploy is Script {

    function run(
            Storage.FunctionsVariables memory _variables,
            uint64 _chainSelector,
            uint _chainIndex,
            address _link,
            address _ccipRouter,
            address _dexSwap,
            Concero.JsCodeHashSum memory jsCodeHashSum,
            bytes32 _ethersHashSum,
            address _pool,
            address _proxy
        ) public returns(Concero concero){

        vm.startBroadcast();
        concero = new Concero(
            _variables,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            jsCodeHashSum,
            _ethersHashSum,
            _dexSwap,
            _pool,
            _proxy
        );
        vm.stopBroadcast();
    }
}
