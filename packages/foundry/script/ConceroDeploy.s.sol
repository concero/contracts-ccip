// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Concero} from "../src/Concero.sol";

contract ConceroDeploy is Script {

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
            address _dexSwap,
            address _pool
        ) public returns(Concero concero){

        vm.startBroadcast();
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
            _dexSwap,
            _pool
        );
        vm.stopBroadcast();
    }
}
