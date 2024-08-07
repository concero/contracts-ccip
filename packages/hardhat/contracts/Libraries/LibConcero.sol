// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibConcero {
    using SafeERC20 for IERC20;

    error TransferToNullAddress();
    error NativeTokenIsNotERC20();
    // TODO: find way to reuse this error
    error InsufficientBalance(uint256 balance, uint256 amount);

    function getBalance(address _token, address _contract) internal view returns (uint256) {
        if (_token == address(0)) {
            return address(_contract).balance;
        } else {
            return IERC20(_token).balanceOf(_contract);
        }
    }

    function transferERC20(address token, uint256 amount, address recipient) internal {
        if (token == address(0)) {
            revert NativeTokenIsNotERC20();
        }

        if (recipient == address(0)) {
            revert TransferToNullAddress();
        }

        IERC20(token).safeTransfer(recipient, amount);
    }

    function transferFromERC20(address token, address from, address to, uint256 amount) internal {
        if (token == address(0)) {
            revert NativeTokenIsNotERC20();
        }

        if (to == address(0)) {
            revert TransferToNullAddress();
        }

        //todo: this MAY be redundant, but need to check
        uint256 balanceBefore = getBalance(token, to);
        IERC20(token).safeTransferFrom(from, to, amount);
        uint256 balanceAfter = getBalance(token, to);

        if (balanceAfter - balanceBefore != amount) {
            revert InsufficientBalance(balanceAfter, amount);
        }
    }
}
