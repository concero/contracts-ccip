// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {MockConceroParentPool} from "../Mocks/MockConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";

contract Base_Test is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    MockConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPoolProxy;
    FunctionsSubscriptions public functionsSubscriptions;

    uint256 forkId;
    address deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER");

    /// @notice these private keys arent being used for anything at the moment
    uint256 deployerPrivateKey = vm.envUint("FORGE_DEPLOYER_PRIVATE_KEY");
    uint256 proxyDeployerPrivateKey = vm.envUint("FORGE_PROXY_DEPLOYER_PRIVATE_KEY");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        /// @dev create and select fork
        forkId = vm.createSelectFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));

        /// @dev We can use vm.prank(<PUBLIC_ADDRESS>) instead of vm.broadcast(<PRIVATE_KEY>)
        vm.prank(proxyDeployer);
        parentPoolProxy = new ParentPoolProxy(address(vm.envAddress("CONCERO_PAUSE_BASE")), proxyDeployer, bytes(""));

        vm.prank(deployer);
        parentPoolImplementation = new MockConceroParentPool(
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

        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(address(parentPoolProxy)).upgradeToAndCall(
            address(parentPoolImplementation), bytes("")
        );

        _addFunctionsConsumer();
    }

    /// @dev run this just to check setUp
    function test_baseTest_setUp() public {
        console.log("testing setUp...");
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _addFunctionsConsumer() private {
        vm.startPrank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions = FunctionsSubscriptions(address(0xf9B8fc078197181C841c296C876945aaa425B278));
        functionsSubscriptions.addConsumer(uint64(vm.envUint("CLF_SUBID_BASE")), address(parentPoolProxy));
        vm.stopPrank();
    }
}
