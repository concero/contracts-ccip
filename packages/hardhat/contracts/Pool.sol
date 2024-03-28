// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidityPool is Ownable, ReentrancyGuard {
  using SafeERC20 for ERC20;

  ERC20 public usdc;
  mapping(address => uint256) private _balances;
  mapping(address => bool) private _whitelist;

  event Deposited(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event Whitelisted(address indexed account);
  event Dewhitelisted(address indexed account);

  constructor(ERC20 _usdc) {
    require(address(_usdc) != address(0), "USDC address cannot be the zero address");
    usdc = _usdc;
  }

  function deposit(uint256 amount) public onlyWhitelisted nonReentrant {
    usdc.safeTransferFrom(msg.sender, address(this), amount);
    _balances[msg.sender] += amount;
    emit Deposited(msg.sender, amount);
  }

  function withdraw(uint256 amount) public onlyWhitelisted nonReentrant {
    require(_balances[msg.sender] >= amount, "Insufficient balance.");
    _balances[msg.sender] -= amount;
    usdc.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  function addToWhitelist(address account) public onlyOwner {
    require(!_whitelist[account], "Account is already whitelisted.");
    _whitelist[account] = true;
    emit Whitelisted(account);
  }

  function removeFromWhitelist(address account) public onlyOwner {
    require(_whitelist[account], "Account is not whitelisted.");
    _whitelist[account] = false;
    emit Dewhitelisted(account);
  }

  modifier onlyWhitelisted() {
    require(_whitelist[msg.sender], "Not whitelisted.");
    _;
  }
}
