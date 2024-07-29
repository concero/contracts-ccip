// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {IAny2EVMMessageReceiver} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ParentPoolStorage} from "contracts/Libraries/ParentPoolStorage.sol";

contract Deposit is DeployParentPool {
    function setUp() public {
        deployPoolsInfra();
    }

    //    function test_startDeposit_Success() public {
    //        uint256 usdcAmount = 100 * 10 ** 6;
    //
    //        vm.prank(user1);
    //        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
    //        vm.stopPrank();
    //
    //        // Add assertions to verify storage changes
    //        // e.g., verify s_depositRequests, s_clfRequestTypes, emitted events, etc.
    //
    //        bytes32 expectedRequestId = keccak256(
    //            abi.encodePacked /* args to match the request ID calculation */()
    //        );
    //
    //        // Verify storage changes
    //        (
    //            address lpAddress,
    //            uint256 childPoolsLiquiditySnapshot,
    //            uint256 usdcAmountToDeposit,
    //            uint256 deadline
    //        ) = IParentPool(address(parentPoolProxy)).s_depositRequests(expectedRequestId);
    //        assertEq(lpAddress, user1);
    //        assertEq(usdcAmountToDeposit, usdcAmount);
    //        //        assertEq(deadline, block.timestamp + DEPOSIT_DEADLINE_SECONDS);
    //
    //        assertEq(
    //            IParentPool(address(parentPoolProxy)).s_clfRequestTypes(expectedRequestId),
    //            IParentPool(address(parentPoolProxy)).RequestType.startDeposit_getChildPoolsLiquidity
    //        );
    //    }

    function test_sendCcipTx() public {
        vm.selectFork(baseForkId);

        deal(vm.envAddress("USDC_BASE"), address(parentPoolProxy), 10000000000000000000000);

        vm.prank(vm.envAddress("MESSENGER_ADDRESS"));
        IParentPool(address(parentPoolProxy)).distributeLiquidity(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            10 * 10 ** 6,
            keccak256(abi.encodePacked("test"))
        );
        vm.stopPrank();
    }

    //    function test_completeDeposit() public {
    //        vm.selectFork(baseForkId);
    //
    //        deal(vm.envAddress("USDC_BASE"), address(parentPoolProxy), 10000000000000000000000);
    //
    //        vm.prank(vm.envAddress("MESSENGER_ADDRESS"));
    //        IParentPool(address(parentPoolProxy)).completeDeposit(
    //            keccak256(abi.encodePacked("test")),
    //            10 * 10 ** 6
    //        );
    //        vm.stopPrank();
    //    }

    function test_ccipReceive() public {
        vm.selectFork(baseForkId);
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));

        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: vm.envAddress("USDC_BASE"),
            amount: 100000000
        });

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked("test")),
            sourceChainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            sender: abi.encode(user1),
            data: abi.encode(address(0), address(0), 0),
            destTokenAmounts: destTokenAmounts
        });

        IAny2EVMMessageReceiver(address(parentPoolProxy)).ccipReceive(message);
    }

    //    function test_startDeposit_RevertAmountBelowMinimum() public {
    //        uint256 usdcAmount = 10 * 10 ** 6; // Below minimum deposit
    //
    //        vm.prank(user1);
    //        vm.expectRevert(
    //            abi.encodeWithSelector(ConceroParentPool_AmountBelowMinimum.selector, MIN_DEPOSIT)
    //        );
    //        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
    //    }

    //    function test_startDeposit_RevertMaxCapReached() public {
    //        uint256 usdcAmount = 1100 * 10 ** 6; // Above maximum deposit
    //
    //        vm.prank(user1);
    //        vm.expectRevert(
    //            abi.encodeWithSelector(ConceroParentPool_MaxCapReached.selector, MAX_DEPOSIT)
    //        );
    //        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
    //    }
}
