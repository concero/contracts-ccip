// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployParentPool is Test {
    ParentPoolDeploy private parentPoolDeploy = new ParentPoolDeploy();
    ParentPoolProxyDeploy private parentPoolProxyDeploy = new ParentPoolProxyDeploy();

    ConceroParentPool public parentPool;
    ParentPoolProxy public parentPoolProxy;

    function deployParentPool() public {
        console.log(address(msg.sender));

        parentPoolProxy = parentPoolProxyDeploy.run(
            address(parentPoolDeploy),
            address(msg.sender),
            bytes("")
        );

        parentPool = parentPoolDeploy.run(
            address(parentPoolProxy),
            address(vm.envAddress("LINK_BASE")),
            bytes32(0),
            uint64(0),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(vm.envAddress("LPTOKEN_BASE")),
            address(vm.envAddress("CONCERO_AUTOMATION_BASE")),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(msg.sender)
        );
    }
}
