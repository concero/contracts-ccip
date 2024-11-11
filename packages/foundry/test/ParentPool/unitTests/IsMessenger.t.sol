// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "../../utils/BaseTest.t.sol";
import {ParentPoolDepositWrapper, IDepositParentPool} from "../wrappers/ParentPoolDepositWrapper.sol";
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
        parentPoolImplementation = new ParentPoolDepositWrapper(
            address(parentPoolProxy),
            address(0x0),
            address(0x0),
            vm.envAddress("LINK_BASE"),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(lpToken),
            vm.envAddress("CONCERO_AUTOMATION_BASE"),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(deployer),
            [messenger1, address(0), address(0)]
        );

        _setProxyImplementation(address(parentPoolImplementation));
        setParentPoolVars();
        deployLpToken();
        addFunctionsConsumer();
    }

    function test_isMessenger_Success() public {
        assertTrue(IDepositParentPool(address(parentPoolProxy)).isMessenger(messenger1));
    }
}
