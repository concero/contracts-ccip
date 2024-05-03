// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ConceroPool is Ownable {
  mapping(address => bool) public approvedSenders;
  mapping(address => bool) public isTokenSupported;
  mapping(address => mapping(address => uint256)) public userBalances; // User balances for each token and ETH

  event Deposited(address indexed token, address indexed from, uint256 amount);
  event Withdrawn(address indexed token, address indexed to, uint256 amount);
  event ApprovedSenderUpdated(address indexed newSender, bool isApproved);

  error Unauthorized();
  error InsufficientBalance();
  error TransferFailed();
  error TokenNotSupported();

  constructor(address _usdc, address _usdt) {
    isTokenSupported[_usdc] = true;
    isTokenSupported[_usdt] = true;
  }

  modifier onlyApprovedSender() {
    if (!approvedSenders[msg.sender]) revert Unauthorized();
    _;
  }

  function setApprovedSender(address _approvedSender, bool _isApproved) external onlyOwner {
    approvedSenders[_approvedSender] = _isApproved;
    emit ApprovedSenderUpdated(_approvedSender, _isApproved);
  }

  function setSupportedToken(address token, bool isSupported) external onlyOwner {
    isTokenSupported[token] = isSupported;
  }

  function depositETH() external payable onlyApprovedSender {
    userBalances[address(0)][msg.sender] += msg.value;
    emit Deposited(address(0), msg.sender, msg.value);
  }

  function withdrawETH(uint256 amount) external onlyApprovedSender {
    if (amount > userBalances[address(0)][msg.sender]) revert InsufficientBalance();

    userBalances[address(0)][msg.sender] -= amount;
    payable(msg.sender).transfer(amount);
    emit Withdrawn(address(0), msg.sender, amount);
  }

  function depositToken(address token, uint256 amount) external onlyApprovedSender {
    if (!isTokenSupported[token]) revert TokenNotSupported();
    bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
    if (!success) revert TransferFailed();

    userBalances[token][msg.sender] += amount;
    emit Deposited(token, msg.sender, amount);
  }

  function withdrawToken(address token, uint256 amount) external onlyApprovedSender {
    if (amount > userBalances[token][msg.sender]) revert InsufficientBalance();

    userBalances[token][msg.sender] -= amount;
    bool success = IERC20(token).transfer(msg.sender, amount);
    if (!success) revert TransferFailed();

    emit Withdrawn(token, msg.sender, amount);
  }
}
