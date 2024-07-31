//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.20;
//
//import {Script, console} from "forge-std/Script.sol";
//import {ConceroMock} from "../test/Mocks/ConceroMock.sol";
//import {ConceroBridge} from "contracts/ConceroBridge.sol";
//import {Storage} from "contracts/Libraries/Storage.sol";
//
//contract ConceroMockDeploy is Script {
//
//    function run(
//            Storage.FunctionsVariables memory _variables,
//            uint64 _chainSelector,
//            uint _chainIndex,
//            address _link,
//            address _ccipRouter,
//            address _dexSwap,
//            address _pool,
//            address _proxy
//        ) public returns(ConceroBridge concero){
//
//        vm.startBroadcast();
//        concero = new ConceroBridge(
//            _variables,
//            _chainSelector,
//            _chainIndex,
//            _link,
//            _ccipRouter,
//            _dexSwap,
//            _pool,
//            _proxy
//        );
//        vm.stopBroadcast();
//    }
//}
