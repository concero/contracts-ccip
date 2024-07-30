// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeployParentPool} from "../deploy/DeployParentPool.sol";
import {ParentPool_DepositWrapper, IDepositParentPool} from "../wrappers/ParentPool_DepositWrapper.sol";
import {Test, console, Vm} from "forge-std/Test.sol";

contract IsMessengerTest is Test, DeployParentPool {
    address messenger1 = vm.envAddress("MESSENGER_0_ADDRESS");
    address messenger2 = vm.envAddress("MESSENGER_1_ADDRESS");
    address messenger3 = vm.envAddress("MESSENGER_2_ADDRESS");
    address notMessenger = user1;

    function setUp() public {
        vm.selectFork(forkId);
        deployParentPoolProxy();
        parentPoolImplementation = new ParentPool_DepositWrapper(
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
            [messenger1, address(0), address(0)]
        );

        setProxyImplementation();
        setParentPoolVars();
        deployAutomation();
        deployLpToken();
        addFunctionsConsumer();
    }

    function test_isMessenger_Success() public {
        assertTrue(IDepositParentPool(address(parentPoolProxy)).isMessenger(messenger1));
    }

    //    function test_isMessenger_Fail() public {
    //        assertFalse(parentPoolImplementation.isMessenger(notMessenger));
    //    }
}
