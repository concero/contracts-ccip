// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidityPool {
  using SafeERC20 for ERC20;

  ERC20 public eth;
  ERC20 public usdc;
  mapping(address => mapping(address => uint256)) private _balances;

  constructor(ERC20 _eth, ERC20 _usdc) {
    eth = _eth;
    usdc = _usdc;
  }

  function deposit(ERC20 token, uint256 amount) public {
    token.safeTransferFrom(msg.sender, address(this), amount);
    _balances[address(token)][msg.sender] += amount;
  }

  function withdraw(ERC20 token, uint256 amount) public {
    require(_balances[address(token)][msg.sender] >= amount, "Insufficient balance.");
    _balances[address(token)][msg.sender] -= amount;
    token.safeTransfer(msg.sender, amount);
  }

  function balanceOf(ERC20 token, address account) public view returns (uint256) {
    return _balances[address(token)][account];
  }
}