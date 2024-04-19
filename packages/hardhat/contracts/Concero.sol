// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";

contract Concero is ConceroCCIP {
  /* todo: allowlisted src + dst chains can be combined into one two-dimensional mapping like so:
      this will still use one SLOAD but would remove the need for two separate mappings
    mapping[uint64][uint64] public allowListedChains;
    and then use it like so:
    modifier onlyAllowListedChain(uint64 _chainSelector, uint64 _chainType) {
      if (!allowListedChains[_chainType][_chainSelector]) revert ChainNotAllowed(_chainSelector);
      _;
    }
  */

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
    bytes32 ccipMessageId = _sendTokenPayLink(_destinationChainSelector, _receiver, _token, _amount);
    emit CCIPSent(ccipMessageId, msg.sender, _receiver, _tokenType, _amount, _destinationChainSelector);
    sendUnconfirmedTX(ccipMessageId, msg.sender, _receiver, _amount, _destinationChainSelector, _token, _tokenType);
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
