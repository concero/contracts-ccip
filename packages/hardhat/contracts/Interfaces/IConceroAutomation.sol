// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IConceroAutomation {
    function addPendingWithdrawalId(bytes32 _withdrawalId) external;
    function getPendingRequests() external view returns (bytes32[] memory _requests);
    function getPendingWithdrawRequestsLength() external view returns (uint256);
    function addWithdrawRequests(
        bytes32[] calldata _withdrawalIds,
        bool[] calldata _isTriggered
    ) external;
}
