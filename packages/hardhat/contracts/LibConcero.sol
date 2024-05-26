// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibConcero {
  function getBalance(address _token, address _contract) internal view returns (uint256) {
    if (_token == address(0)) {
      return _contract.balance;
    } else {
      return IERC20(_token).balanceOf(_contract);
    }
  }
}
