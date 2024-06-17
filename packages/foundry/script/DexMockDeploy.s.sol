// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DEXMock} from "../test/Mocks/DEXMock.sol";

contract DexSwapDeploy is Script {

    function run() public returns(DEXMock dexSwap){
        vm.startBroadcast();
        dexSwap = new DEXMock();
        vm.stopBroadcast();
    }
}
