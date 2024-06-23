// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ParentPool} from "contracts/ParentPool.sol";

contract ParentPoolDeploy is Script {

    
    function run(
        address _proxy,
        address _link,
        bytes32 _donId,
        uint64 _subscriptionId,
        address _functionsRouter,
        address _ccipRouter,
        address _usdc, 
        address _lpToken, 
        address _automation,
        address _orchestrator,
        address _owner
    ) public returns(ParentPool pool){
        vm.startBroadcast();
        pool = new ParentPool(
            _proxy,
            _link,
            _donId,
            _subscriptionId,
            _functionsRouter,
            _ccipRouter,
            _usdc,
            _lpToken,
            _automation,
            _orchestrator,
            _owner
        );
        vm.stopBroadcast();
    }
}
