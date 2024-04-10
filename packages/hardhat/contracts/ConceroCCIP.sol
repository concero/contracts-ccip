// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPInternal} from "./CCIPInternal.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {CFunctions} from "./CFunctions.sol";

contract ConceroCCIP is CCIPInternal, ConfirmedOwner {
  address internal internalFunctionContract;
  CFunctions private cFunctions;

  modifier onlyFunctionContract() {
    if (msg.sender != internalFunctionContract) {
      revert NotFunctionContract(msg.sender);
    }
    _;
  }

  constructor(address _link, address _ccipRouter) CCIPInternal(_link, _ccipRouter) ConfirmedOwner(msg.sender) {}

  receive() external payable {}

  function setAllowDestinationChain(uint64 _dstChainSelector, bool allowed) external onlyOwner {
    allowListedDstChains[_dstChainSelector] = allowed;
  }

  function setAllowSourceChain(uint64 _srcChainSelector, bool allowed) external onlyOwner {
    allowListedSrcChains[_srcChainSelector] = allowed;
  }

  function setAllowListSender(address _sender, bool allowed) external onlyOwner {
    allowListedSenderContracts[_sender] = allowed;
  }

  function setInternalFunctionContract(address _internalFunctionContract) external onlyOwner {
    internalFunctionContract = _internalFunctionContract;
    cFunctions = CFunctions(_internalFunctionContract);
  }

  function setDstConceroCCIPContract(uint64 _chainSelector, address _dstConceroCCIPContract) external onlyOwner {
    dstConceroCCIPContracts[_chainSelector] = _dstConceroCCIPContract;
  }

  function startTransaction(
    address _token,
    uint256 _amount,
    uint64 _destinationChainSelector,
    address _receiver
  ) external payable tokenAmountSufficiency(_token, _amount) {
    // move to OZ save transfer
    bool isOK = IERC20(_token).transferFrom(msg.sender, address(this), _amount);

    require(isOK, "Transfer failed");

    bytes32 ccipMessageId = _sendTokenPayLink(_destinationChainSelector, _receiver, _token, _amount);

    if (address(cFunctions) == address(0)) {
      revert("cFunctions address not set");
    }
    cFunctions.sendUnconfirmedTX(ccipMessageId, msg.sender, _receiver, _amount, _destinationChainSelector, _token);
  }

  function sendTokenToEoa(bytes32 _ccipMessageId, address _sender, address _recipient, address _token, uint256 _amount) external onlyFunctionContract {
    bool isOk = IERC20(_token).transfer(_recipient, _amount);
    require(isOk, "Transfer failed");
    emit TXReleased(_ccipMessageId, _sender, _recipient, _token, _amount);
  }

  function withdraw(address _owner) public onlyOwner {
    uint256 amount = address(this).balance;

    if (amount == 0) {
      revert NothingToWithdraw();
    }

    (bool sent, ) = _owner.call{value: amount}("");

    if (!sent) {
      revert FailedToWithdrawEth(msg.sender, _owner, amount);
    }
  }

  function withdrawToken(address _owner, address _token) public onlyOwner {
    uint256 amount = IERC20(_token).balanceOf(address(this));

    if (amount == 0) {
      revert NothingToWithdraw();
    }

    IERC20(_token).transfer(_owner, amount);
  }
}
