// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";

contract ChildPoolDeploy is Script {

    
    function run(
        address _orchestratorProxy,
        address _masterPoolProxyAddress,
        address _childProxy,
        address _link,
        address _ccipRouter,
        uint64 _destinationChainSelector,
        address _usdc, 
        address _owner
    ) public returns(ConceroChildPool child){
        vm.startBroadcast();
        child = new ConceroChildPool(
            _orchestratorProxy,
            _masterPoolProxyAddress,
            _childProxy, 
            _link, 
            _ccipRouter,
            _destinationChainSelector, 
            _usdc, 
            _owner
        );
        vm.stopBroadcast();
    }
}
