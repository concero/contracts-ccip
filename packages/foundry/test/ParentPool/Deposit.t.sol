// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {ParentPool_DepositWrapper, IDepositParentPool} from "./wrappers/ParentPool_DepositWrapper.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {Client} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from
    "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

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
            // address(conceroCLA),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)],
            0
        );

        setProxyImplementation();
        setParentPoolVars();
        // deployAutomation();
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
        ParentPool_DepositWrapper.DepositRequest memory depositRequest =
            IDepositParentPool(address(parentPoolProxy)).getDepositRequest(requestId);

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

    function test_ccipReceive() public {
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));

        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({token: vm.envAddress("USDC_BASE"), amount: 100000000});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked("test")),
            sourceChainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            sender: abi.encode(user1),
            data: abi.encode(address(0), address(0), 0),
            destTokenAmounts: destTokenAmounts
        });

        IAny2EVMMessageReceiver(address(parentPoolProxy)).ccipReceive(message);
    }
}
