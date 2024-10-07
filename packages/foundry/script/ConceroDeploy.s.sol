// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {InfraStorage} from "contracts/Libraries/InfraStorage.sol";

contract ConceroDeploy is Script {
    function run(
        InfraStorage.FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    ) public returns (ConceroBridge concero) {
        vm.startBroadcast();
        concero = new ConceroBridge(
            _variables,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            _dexSwap,
            _pool,
            _proxy,
            _messengers
        );
        vm.stopBroadcast();
    }
}
