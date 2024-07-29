// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

contract Deposit is DeployParentPool {
    function setUp() public {
        deployPoolsInfra();
    }

    function test_startDeposit_Success() public {
        uint256 usdcAmount = 100 * 10 ** 6;

        vm.prank(user1);
        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);

        vm.stopPrank();
        // Add assertions to verify storage changes
        // e.g., verify s_depositRequests, s_clfRequestTypes, emitted events, etc.
    }
}
