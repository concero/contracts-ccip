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

    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;
}

interface IParentPoolCLFCLAViewDelegate {
    function calculateWithdrawableAmountViaDelegateCall(
        uint256 childPoolsBalance,
        uint256 clpAmount
    ) external view returns (uint256);

    function checkUpkeepViaDelegate() external view returns (bool, bytes memory);
}
