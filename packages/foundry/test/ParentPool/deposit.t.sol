// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../script/ParentPoolDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {DeployParentPool} from "./DeployParentPool.t.sol";

contract DepositTest is DeployParentPool {
    function setUp() public {
        deployParentPool();
    }

    function testDeposit() public {
        console.log("test_deposit");
    }
}
