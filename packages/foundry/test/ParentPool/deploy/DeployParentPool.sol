// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";
import {Test, console} from "forge-std/Test.sol";
import {LPToken} from "contracts/LPToken.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {Register, CCIPLocalSimulatorFork} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";

contract DeployParentPool is Test {
    ConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPoolProxy;

    ChildPoolProxy public childPoolProxy_ARBUTRUM;
    ConceroChildPool public childPool_ARBUTRUM;

    LPToken public lpToken;
    ConceroAutomation public conceroCLA;
    FunctionsSubscriptions public functionsSubscriptions;

    uint256 public arbitrumForkId = vm.createFork(vm.envString("LOCAL_ARBITRUM_FORK_RPC_URL"));
    uint256 public baseForkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    uint256 internal deployerPrivateKey = vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY");
    uint256 internal proxyDeployerPrivateKey = vm.envUint("FORGE_PROXY_DEPLOYER_PRIVATE_KEY");
    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");

    function deployPoolsInfra() public {
        _deployParentPool();
        _setParentPoolVars();
        _deployAutomation();
        _deployLpToken();
        //        _addFunctionsConsumer();
        _fundLinkParentProxy(100000000000000000000);

        _deployChildPools();
    }

    function _deployParentPool() private {
        vm.selectFork(baseForkId);
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
            uint64(vm.envUint("CLF_SUBID_BASE")),
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

        vm.stopBroadcast();
    }

    function _setParentPoolVars() private {
        vm.selectFork(baseForkId);
        vm.startBroadcast(deployerPrivateKey);
        IParentPool(address(parentPoolProxy)).setPools(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            address(parentPoolImplementation),
            false
        );

        IParentPool(address(parentPoolProxy)).setConceroContractSender(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            address(user1),
            1
        );
        vm.stopBroadcast();
    }

    function _deployAutomation() private {
        vm.selectFork(baseForkId);
        vm.startBroadcast(deployerPrivateKey);
        conceroCLA = new ConceroAutomation(
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE_SEPOLIA")),
            0,
            vm.envAddress("CLF_ROUTER_BASE"),
            address(parentPoolProxy),
            address(deployer)
        );
        vm.stopBroadcast();
    }

    function _deployLpToken() private {
        vm.selectFork(baseForkId);
        vm.startBroadcast(deployerPrivateKey);
        lpToken = new LPToken(deployer, address(parentPoolProxy));
        vm.stopBroadcast();
    }

    function _addFunctionsConsumer() private {
        vm.selectFork(baseForkId);
        vm.startPrank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions = FunctionsSubscriptions(
            address(0xf9B8fc078197181C841c296C876945aaa425B278)
        );
        functionsSubscriptions.addConsumer(
            uint64(vm.envUint("CLF_SUBID_BASE")),
            address(parentPoolProxy)
        );
        vm.stopPrank();
    }

    function _fundLinkParentProxy(uint256 amount) internal {
        vm.selectFork(baseForkId);
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), amount);
    }

    function _deployChildPools() private {
        vm.selectFork(arbitrumForkId);
        vm.startBroadcast(deployerPrivateKey);
        childPoolProxy_ARBUTRUM = new ChildPoolProxy(
            address(vm.envAddress("CONCERO_PAUSE_ARBITRUM")),
            proxyDeployer,
            bytes("")
        );
        vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);

        childPool_ARBUTRUM = new ConceroChildPool(
            address(this),
            address(childPoolProxy_ARBUTRUM),
            vm.envAddress("LINK_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_BASE"),
            address(deployer)
        );

        vm.stopBroadcast();

        vm.startBroadcast(proxyDeployerPrivateKey);

        ITransparentUpgradeableProxy(address(childPoolProxy_ARBUTRUM)).upgradeToAndCall(
            address(childPool_ARBUTRUM),
            bytes("")
        );

        vm.stopBroadcast();
    }
}
