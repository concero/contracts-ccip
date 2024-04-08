// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConceroCCIP} from "./ConceroCCIP.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ConfirmedOwner} from '@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol';

contract ConceroBridge is ConceroCCIP, ConfirmedOwner {

    constructor(
        address _link,
        address _ccipRouter,
        address _externalConceroBridge
    ) ConceroCCIP(_link, _ccipRouter, _externalConceroBridge) ConfirmedOwner(msg.sender)
    {}

    receive() external payable {}

    function allowDestinationChain(
        uint64 _dstChainSelector,
        bool allowed
    ) external onlyOwner {
        allowListedDstChains[_dstChainSelector] = allowed;
    }

    function allowSourceChain(
        uint64 _srcChainSelector,
        bool allowed
    ) external onlyOwner {
        allowListedSrcChains[_srcChainSelector] = allowed;
    }

    function allowListSender(address _sender, bool allowed) external onlyOwner {
        allowListedSenders[_sender] = allowed;
    }

    function setExternalConceroBridge(address _externalConceroBridge) external onlyOwner {
        externalConceroBridge = _externalConceroBridge;
    }

    function setInternalFunctionContract(address _internalFunctionContract) external onlyOwner {
        internalFunctionContract = _internalFunctionContract;
    }


    function startTransaction(
        address _token,
        uint256 _amount,
        uint64 _destinationChainSelector,
        address _receiver
    ) external payable tokenAmountSufficiency(_token, _amount) {
        bool isOK = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        require(isOK, "Transfer failed");

        _sendTokenPayLink(
            _destinationChainSelector,
            _receiver,
            _token,
            _amount
        );

        // sendRequest() for trigger functions
    }

    function withdraw(address _owner) public onlyOwner {
        uint256 amount = address(this).balance;

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        (bool sent,) = _owner.call{value: amount}("");

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
