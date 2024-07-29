// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";
import {Test, console} from "forge-std/Test.sol";
import {LPToken} from "contracts/LPToken.sol";

contract DeployParentPool is Test {
    ConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPoolProxy;
    LPToken public lpToken;
    ConceroAutomation public conceroCLA;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function deployParentPool() internal {
        uint256 deployerPrivateKey = vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY");
        uint256 proxyDeployerPrivateKey = vm.envUint("FORGE_PROXY_DEPLOYER_PRIVATE_KEY");
        uint256 forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
        address deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
        address proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER");

        vm.selectFork(forkId);
        vm.startBroadcast(proxyDeployerPrivateKey);

        // Deploy ParentPoolProxy
        parentPoolProxy = new ParentPoolProxy(
            address(vm.envAddress("CONCERO_PAUSE_BASE")),
            proxyDeployer,
            bytes("")
        );
        vm.stopBroadcast();

        // Deploy LPToken and ConceroAutomation
        vm.startBroadcast(deployerPrivateKey);
        lpToken = new LPToken(deployer, address(parentPoolProxy));

        // Deploy ConceroAutomation
        conceroCLA = new ConceroAutomation(
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE_SEPOLIA")),
            0,
            vm.envAddress("CLF_ROUTER_BASE"),
            address(parentPoolProxy),
            address(deployer)
        );

        // Deploy ConceroParentPool
        parentPoolImplementation = new ConceroParentPool(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE_SEPOLIA")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(lpToken),
            address(conceroCLA),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer)
        );
        vm.stopBroadcast();

        // Upgrade Proxy to new Implementation
        vm.startBroadcast(proxyDeployerPrivateKey);
        ITransparentUpgradeableProxy(address(parentPoolProxy)).upgradeToAndCall(
            address(parentPoolImplementation),
            bytes("")
        );

        // Mint LP Tokens
        //        lpToken.mint(user1, 100 * 10 ** lpToken.decimals());
        vm.stopBroadcast();
    }
}
