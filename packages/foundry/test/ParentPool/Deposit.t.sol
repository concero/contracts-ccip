// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {ParentPool_DepositWrapper, IDepositParentPool} from "./wrappers/ParentPool_DepositWrapper.sol";
import {Test, console, Vm} from "forge-std/Test.sol";

contract Deposit is DeployParentPool {
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
            [vm.envAddress("MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

        setProxyImplementation();
        setParentPoolVars();
        deployAutomation();
        deployLpToken();
        addFunctionsConsumer();
    }

    function test_startDeposit_Success() public {
        uint256 usdcAmount = 100 * 10 ** 6;
        vm.recordLogs();

        vm.prank(user1);
        IDepositParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
        vm.stopPrank();
        // Get the emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Verify the emitted logs
        assertEq(entries.length, 4);
        bytes32 requestId = entries[0].topics[1];

        // Verify storage changes using the emitted requestId
        ParentPool_DepositWrapper.DepositRequest memory depositRequest = IDepositParentPool(
            address(parentPoolProxy)
        ).getDepositRequest(requestId);

        assertEq(depositRequest.lpAddress, address(user1));
        assertEq(depositRequest.usdcAmountToDeposit, usdcAmount);
    }

    function test_startDeposit_RevertOnMinDeposit() public {
        uint256 usdcAmount = 1;

        vm.prank(user1);
        vm.expectRevert();
        IDepositParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
    }

    function test_startDeposit_RevertNonProxyCall() public {
        uint256 usdcAmount = 100 * 10 ** 6;
        vm.prank(user1);
        vm.expectRevert();
        parentPoolImplementation.startDeposit(usdcAmount);
    }
}
