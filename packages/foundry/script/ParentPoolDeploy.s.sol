// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";

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
        address _orchestrator,
        address _owner,
        address[3] memory _msgrs,
        uint8 _slotId
    ) public returns (ConceroParentPool pool) {
        uint256 forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
        vm.selectFork(forkId);

        vm.startBroadcast(vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY"));
        pool = new ConceroParentPool(
            _proxy,
            _link,
            _donId,
            _subscriptionId,
            _functionsRouter,
            _ccipRouter,
            _usdc,
            _lpToken,
            _orchestrator,
            _owner,
            _slotId,
            _msgrs
        );
        vm.stopBroadcast();
    }
}
