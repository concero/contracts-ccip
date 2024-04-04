// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.19;

import { ConceroCCIP } from "./ConceroCCIP.sol";
import { ConceroFunctions } from "./ConceroFunctions.sol";
import { IERC20 } from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract ConceroBridge is ConceroCCIP, ConceroFunctions {
	string srcChainRequestSourceCode = "console.log('test')";

	constructor(
		address _link,
		address _ccipRouter,
		address _functionsRouter,
		bytes32 _donId
	)
		ConceroCCIP(_link, _ccipRouter)
		ConceroFunctions(_functionsRouter, _donId)
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
	}

	function withdraw(address _owner) public onlyOwner {
		uint256 amount = address(this).balance;

		if (amount == 0) {
			revert NothingToWithdraw();
		}

		(bool sent, ) = _owner.call{ value: amount }("");

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

	function handleTransaction(
		string[] calldata args,
		uint64 subscriptionId
	) external onlyOwner {
		sendRequest(srcChainRequestSourceCode, subscriptionId, args);
	}
}
