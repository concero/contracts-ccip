// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */

pragma solidity 0.8.20;

interface IParentPoolCLFCLA {
    function sendCLFRequest(bytes[] memory args) external returns (bytes32);

    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);
}

interface IParentPoolCLFCLAViewDelegate {
    function calculateWithdrawableAmount(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);
}
