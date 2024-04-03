// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDiamond {
    function processTransaction(address to, uint256 value, bytes memory data) external payable;
}
