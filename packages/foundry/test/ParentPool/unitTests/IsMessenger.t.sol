// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "../BaseTest.t.sol";
import {ParentPool_Wrapper, IParentPoolWrapper} from "../wrappers/ParentPool_Wrapper.sol";
import {Test, console, Vm} from "forge-std/Test.sol";

contract IsMessengerTest is BaseTest {
    address messenger1 = vm.envAddress("POOL_MESSENGER_0_ADDRESS");
    address messenger2 = vm.envAddress("MESSENGER_1_ADDRESS");
    address messenger3 = vm.envAddress("MESSENGER_2_ADDRESS");
    address notMessenger = user1;
    uint8 slotId = 0;

    function setUp() public override {
        vm.selectFork(forkId);
        deployParentPoolProxy();
        parentPoolImplementation = new ParentPool_Wrapper(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(lpToken),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer),
            slotId,
            [messenger1, address(0), address(0)]
        );

        setProxyImplementation(address(parentPoolImplementation));

        /// @dev set initial child pool
        (address arbitrumChildProxy, address arbitrumChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_PROXY_ARBITRUM"),
            vm.envAddress("LINK_ARBITRUM"),
            vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_ARBITRUM")
        );
        setParentPoolVars(uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")), arbitrumChildProxy);

        deployLpToken();
        addFunctionsConsumer();
    }

    function test_isMessenger_Success() public {
        assertTrue(IParentPoolWrapper(address(parentPoolProxy)).isMessenger(messenger1));
    }

    //    function test_isMessenger_Fail() public {
    //        assertFalse(parentPoolImplementation.isMessenger(notMessenger));
    //    }
}
