// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IConceroAutomation {
    function addPendingWithdrawalId(bytes32 _withdrawalId) external;
}
