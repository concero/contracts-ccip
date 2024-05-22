// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Concero} from "../src/Concero.sol";

contract ConceroPoolDeploy is Script {

    function run(address _link,address _ccipRouter) public returns(Concero concero){
        vm.startBroadcast();
        concero = new Concero(_link, _ccipRouter);
        vm.stopBroadcast();
    }
}
