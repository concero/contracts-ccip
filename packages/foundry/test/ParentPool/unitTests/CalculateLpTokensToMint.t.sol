// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BaseTest} from "../BaseTest.t.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {ParentPool_Wrapper} from "../wrappers/ParentPool_Wrapper.sol";

contract CalculateLpTokensToMintTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
								SETUP
   //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(forkId);
        deployParentPoolProxy();
        deployLpToken();

        parentPoolImplementation = new ParentPool_Wrapper(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(lpToken),
            vm.envAddress("CONCERO_AUTOMATION_BASE"),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

        setProxyImplementation(address(parentPoolImplementation));
        setParentPoolVars();
        addFunctionsConsumer();
    }

    function test_CalculateLpTokensToMint() public {}
}
