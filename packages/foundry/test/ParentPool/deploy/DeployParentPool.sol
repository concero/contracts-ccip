// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {Test, console} from "forge-std/Test.sol";

contract DeployParentPool is Test {
    ConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPoolProxy;

    function deployParentPool() internal {
        uint256 deployerPrivateKey = vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY");
        uint256 proxyDeployerPrivateKey = vm.envUint("FORGE_PROXY_DEPLOYER_PRIVATE_KEY");
        uint256 forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
        address deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
        address proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER");

        vm.selectFork(forkId);

        vm.startBroadcast(proxyDeployerPrivateKey);
        parentPoolProxy = new ParentPoolProxy(
            address(vm.envAddress("CONCERO_PAUSE_BASE")),
            proxyDeployer,
            bytes("")
        );
        vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);
        parentPoolImplementation = new ConceroParentPool(
            address(parentPoolProxy),
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

        vm.startBroadcast(proxyDeployerPrivateKey);
        ITransparentUpgradeableProxy(address(parentPoolProxy)).upgradeToAndCall(
            address(parentPoolImplementation),
            bytes("")
        );
        vm.stopBroadcast();
    }
}
