// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";
import {Test, console} from "forge-std/Test.sol";
import {LPToken} from "contracts/LPToken.sol";
import {CCIPLocalSimulator} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";

contract DeployParentPool is Test {
    ConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPoolProxy;
    LPToken public lpToken;
    ConceroAutomation public conceroCLA;
    FunctionsSubscriptions public functionsSubscriptions;
    CCIPLocalSimulator public ccipLocalSimulator;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    uint256 internal deployerPrivateKey = vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY");
    uint256 internal proxyDeployerPrivateKey = vm.envUint("FORGE_PROXY_DEPLOYER_PRIVATE_KEY");
    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");
    uint256 internal forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));

    function deployPoolsInfra() public {
        vm.selectFork(forkId);
        deployParentPoolProxy();
        _deployParentPool();
        setProxyImplementation();
        setParentPoolVars();
        _deployCcipLocalSimulation();
        deployAutomation();
        deployLpToken();
        addFunctionsConsumer();
        _fundLinkParentProxy(100000000000000000000);
    }

    address public customParentPoolAddress;

    function deployParentPoolProxy() public {
        vm.startBroadcast(proxyDeployerPrivateKey);

        parentPoolProxy = new ParentPoolProxy(
            address(vm.envAddress("CONCERO_PAUSE_BASE")),
            proxyDeployer,
            bytes("")
        );

        vm.stopBroadcast();
    }

    function _deployParentPool() private {
        // Deploy the default ConceroParentPool if no custom address is provided
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
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
        vm.stopBroadcast();
    }
    function setProxyImplementation() public {
        vm.startBroadcast(proxyDeployerPrivateKey);
        ITransparentUpgradeableProxy(address(parentPoolProxy)).upgradeToAndCall(
            address(parentPoolImplementation),
            bytes("")
        );
        vm.stopBroadcast();
    }

    function setParentPoolVars() public {
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

    function deployAutomation() public {
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

    function deployLpToken() public {
        vm.startBroadcast(deployerPrivateKey);
        lpToken = new LPToken(deployer, address(parentPoolProxy));
        vm.stopBroadcast();
    }
    function addFunctionsConsumer() public {
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

    function _deployCcipLocalSimulation() private {
        ccipLocalSimulator = new CCIPLocalSimulator();
        ccipLocalSimulator.configuration();
        ccipLocalSimulator.supportNewToken(vm.envAddress("USDC_BASE"));
    }

    function _fundLinkParentProxy(uint256 amount) internal {
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), amount);
    }
}
