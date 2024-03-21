// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSDC is ERC20 {
    constructor(uint256 initialSupply) ERC20("TestUSDC", "USDC") {
        _mint(msg.sender, initialSupply);
    }
    function mint(address to, uint256 amount) public {
        // Add a require statement here to restrict who can call this function
        _mint(to, amount);
    }
}