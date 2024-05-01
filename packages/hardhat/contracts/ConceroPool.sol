// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ConceroPool is Ownable {
  address public approvedSender;
  mapping(address => bool) public isTokenSupported;
  mapping(address => uint256) public tokenBalances;

  event Deposited(address indexed token, address indexed from, uint256 amount);
  event Withdrawn(address indexed token, address indexed to, uint256 amount);
  event ApprovedSenderChanged(address indexed previousSender, address indexed newSender);

  error Unauthorized();
  error InsufficientBalance();
  error TransferFailed();
  error TokenNotSupported();

  constructor(address _usdc, address _usdt) {
    isTokenSupported[_usdc] = true;
    isTokenSupported[_usdt] = true;
  }

  modifier onlyApprovedSender() {
    require(msg.sender == approvedSender, "Caller is not the approved sender");
    _;
  }

  function setApprovedSender(address _approvedSender) external onlyOwner {
    approvedSender = _approvedSender;
    emit ApprovedSenderChanged(approvedSender, _approvedSender);
  }

  function setSupportedToken(address token, bool isSupported) external onlyOwner {
    isTokenSupported[token] = isSupported;
  }

  function depositETH() external payable onlyApprovedSender {
    emit Deposited(address(0), msg.sender, msg.value);
  }

  function withdrawETH(uint256 amount) external onlyApprovedSender {
    if (amount > address(this).balance) revert InsufficientBalance();

    payable(msg.sender).transfer(amount);
    emit Withdrawn(address(0), msg.sender, amount);
  }

  function depositToken(address token, uint256 amount) external onlyApprovedSender {
    if (!isTokenSupported[token]) revert TokenNotSupported();
    bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
    if (!success) revert TransferFailed();

    tokenBalances[token] += amount;
    emit Deposited(token, msg.sender, amount);
  }

  function withdrawToken(address token, uint256 amount) external onlyApprovedSender {
    if (!isTokenSupported[token]) revert TokenNotSupported();
    tokenBalances[token] -= amount;
    bool success = IERC20(token).transfer(msg.sender, amount);
    if (!success) revert TransferFailed();

    emit Withdrawn(token, msg.sender, amount);
  }
}
