// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployParentPool is Test {
    ConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPool;

    function deployParentPool() internal {
        uint256 deployerPrivateKey = vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY");
        uint256 forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
        address deployer = vm.envAddress("FORGE_DEPLOYER");
        address proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER");

        vm.selectFork(forkId);
        vm.startBroadcast(deployerPrivateKey);

        parentPoolImplementation = new ConceroParentPool(
            address(parentPool),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE_SEPOLIA")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(vm.envAddress("LPTOKEN_BASE")),
            address(vm.envAddress("CONCERO_AUTOMATION_BASE")),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer)
        );

        parentPool = new ParentPoolProxy(
            address(parentPoolImplementation),
            proxyDeployer,
            bytes("")
        );

        parentPoolImplementation = new ConceroParentPool(
            address(parentPool),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE_SEPOLIA")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(vm.envAddress("LPTOKEN_BASE")),
            address(vm.envAddress("CONCERO_AUTOMATION_BASE")),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer)
        );

        vm.stopBroadcast();
    }
}
