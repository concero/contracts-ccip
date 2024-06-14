// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LancaPool is ERC20, ERC20Burnable, Ownable {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}
