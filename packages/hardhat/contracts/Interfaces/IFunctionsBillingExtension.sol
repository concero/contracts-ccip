// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IFunctionsBilling, FunctionsBilling} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsBilling.sol";

interface IFunctionsBillingExtension is IFunctionsBilling {
    function getConfig() external view returns (FunctionsBilling.Config memory);
}
