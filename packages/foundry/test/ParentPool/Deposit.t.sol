// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployParentPool} from "./deploy/DeployParentPool.sol";

contract Deposit is DeployParentPool {
    function beforeTestSetup() public {
        deployParentPool();
    }
}
