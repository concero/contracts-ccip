// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {ParentPoolStorage} from "contracts/Libraries/ParentPoolStorage.sol";

contract Deposit is DeployParentPool, ConceroParentPool {
    function setUp() public {
        deployPoolsInfra();
    }

    function test_startDeposit_Success() public {
        uint256 usdcAmount = 100 * 10 ** 6;

        vm.prank(user1);
        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);

        vm.stopPrank();

        bytes32 expectedRequestId = keccak256(
            abi.encodePacked /* args to match the request ID calculation */()
        );

        // Verify storage changes
        (
            address lpAddress,
            uint256 childPoolsLiquiditySnapshot,
            uint256 usdcAmountToDeposit,
            uint256 deadline
        ) = IParentPool(address(parentPoolProxy)).s_depositRequests(expectedRequestId);
        assertEq(lpAddress, user1);
        assertEq(usdcAmountToDeposit, usdcAmount);
        assertEq(deadline, block.timestamp + DEPOSIT_DEADLINE_SECONDS);

        assertEq(
            IParentPool(address(parentPoolProxy)).s_clfRequestTypes(expectedRequestId),
            IParentPool(address(parentPoolProxy)).RequestType.startDeposit_getChildPoolsLiquidity
        );
    }
    //
    //    function test_startDeposit_RevertAmountBelowMinimum() public {
    //        uint256 usdcAmount = 10 * 10 ** 6; // Below minimum deposit
    //
    //        vm.prank(user1);
    //        vm.expectRevert(
    //            abi.encodeWithSelector(ConceroParentPool_AmountBelowMinimum.selector, MIN_DEPOSIT)
    //        );
    //        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
    //    }
    //
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
