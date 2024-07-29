// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";

contract Deposit is DeployParentPool {
    function setUp() public {
        deployParentPool();
    }

    function test_RunDeploy() public {
        console.log(address(parentPoolImplementation));
    }
}
