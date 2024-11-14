// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest} from "../../utils/BaseTest.t.sol";
import {ParentPoolDepositWrapper, IDepositParentPool} from "../wrappers/ParentPoolDepositWrapper.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

contract CalculateWithdrawableAmount is BaseTest {
    address private users = makeAddr("users");

    function test_CalculateWithdrawableAmount() public {
        _mintLpToken(address(parentPoolProxy), 100000000000);
        _mintUSDC(address(parentPoolProxy), 100000000000);

        IParentPool(address(parentPoolProxy)).calculateWithdrawableAmount(1000, 1000);
    }
}
