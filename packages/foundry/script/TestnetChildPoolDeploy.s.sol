// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";

contract TestnetChildPoolDeploy is Script {

    address _orchestratorProxy = address(0);
    address _childProxy = 0xb9b4eb0088cD3d98fF7A30a8e7DeE5eCdcC290B2;
    address _link = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address _ccipRouter = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;
    address _usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address _owner = 0x5FA769922a6428758fb44453815e2c436c57C3c7;

    function run() public returns(ConceroChildPool child){
        vm.startBroadcast();
        child = new ConceroChildPool(
            _orchestratorProxy,
            _childProxy,
            _link,
            _ccipRouter,
            _usdc,
            _owner
        );
        vm.stopBroadcast();
    }
}
