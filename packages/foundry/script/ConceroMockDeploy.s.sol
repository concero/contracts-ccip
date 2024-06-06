// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ConceroMock} from "../test/Mocks/ConceroMock.sol";
import {Concero} from "contracts/Concero.sol";

contract ConceroMockDeploy is Script {

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
            address _dexSwap,
            Concero.JsCodeHashSum memory jsCodeHashSum
    ) public returns(ConceroMock concero){

        vm.startBroadcast();
        concero = new ConceroMock(
            _functionsRouter,
            _donHostedSecretsVersion,
            _donId,
            _donHostedSecretsSlotId,
            _subscriptionId,
            _chainSelector,
            _chainIndex,
            _link,
            _ccipRouter,
            _dexSwap,
            jsCodeHashSum
        );
        vm.stopBroadcast();
    }
}
