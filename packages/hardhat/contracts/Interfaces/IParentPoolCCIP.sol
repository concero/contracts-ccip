// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IParentPoolCCIP {
    function calculateLpAmount(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256);
}
