// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ParentPool} from "contracts/ParentPool.sol";

contract ParentPoolDeploy is Script {
    function run(
        address _parentPoolProxy,
        address _parentPoolCLFCLA,
        address _automationForwarder,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _lpToken,
        address _infraProxy,
        address _clfRouter,
        address _owner,
        address[3] memory _messengers
    ) public returns (ParentPool pool) {
        uint256 forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
        vm.selectFork(forkId);

        vm.startBroadcast(vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY"));
        pool = new ParentPool(
            _parentPoolProxy,
            _parentPoolCLFCLA,
            _automationForwarder,
            _link,
            _ccipRouter,
            _usdc,
            _lpToken,
            _infraProxy,
            _clfRouter,
            _owner,
            _messengers
        );
        vm.stopBroadcast();
    }
}
