// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";

contract Concero is ConceroCCIP {
  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex,
    address _link,
    address _ccipRouter
  ) ConceroCCIP(_functionsRouter, _donHostedSecretsVersion, _donId, _subscriptionId, _chainSelector, _chainIndex, _link, _ccipRouter) {}

  function startTransaction(
    address _token,
    CCIPToken _tokenType,
    uint256 _amount,
    uint64 _destinationChainSelector,
    address _receiver
  ) external payable tokenAmountSufficiency(_token, _amount) {
    //todo: maybe move to OZ safeTransfer (but research needed)
    bool isOK = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    require(isOK, "Transfer failed");

    if (msg.value < (1500000 * tx.gasprice)) {
      revert InsufficientFee();
    }

    bytes32 ccipMessageId = _sendTokenPayLink(_destinationChainSelector, _receiver, _token, _amount);
    emit CCIPSent(ccipMessageId, msg.sender, _receiver, _tokenType, _amount, _destinationChainSelector);

    sendUnconfirmedTX(ccipMessageId, msg.sender, _receiver, _amount, _destinationChainSelector, _tokenType);
  }

  function withdraw(address _owner) public onlyOwner {
    uint256 amount = address(this).balance;
    if (amount == 0) revert NothingToWithdraw();
    (bool sent, ) = _owner.call{value: amount}("");
    if (!sent) revert FailedToWithdrawEth(msg.sender, _owner, amount);
  }

  function withdrawToken(address _owner, address _token) public onlyOwner {
    uint256 amount = IERC20(_token).balanceOf(address(this));
    if (amount == 0) revert NothingToWithdraw();
    IERC20(_token).transfer(_owner, amount);
  }
}
