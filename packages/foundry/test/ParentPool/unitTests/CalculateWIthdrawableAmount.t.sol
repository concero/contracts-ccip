// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "../BaseTest.t.sol";
import {ParentPool_DepositWrapper, IDepositParentPool} from "../wrappers/ParentPool_DepositWrapper.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

contract CalculateWithdrawableAmount is BaseTest {
    address private users = makeAddr("users");

    function test_CalculateWithdrawableAmount() public {
        mintLpToken(address(parentPoolProxy), 100000000000);
        mintUSDC(address(parentPoolProxy), 100000000000);

        IParentPool(address(parentPoolProxy)).calculateWithdrawableAmount(1000, 1000);
    }
}
