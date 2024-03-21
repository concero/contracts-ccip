// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { EnumerableMap } from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/utils/structs/EnumerableMap.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { IERC20 } from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControlInternal } from "./bases/AccessControl/AccessControlInternal.sol";
import { CCIPInternal } from "./bases/CCIP/CCIPInternal.sol";
import { UseStorage } from "./core/UseStorage.sol";


contract CCIPFacet is AccessControlInternal, CCIPInternal, UseStorage {
	using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
	using SafeERC20 for IERC20;

	/// @dev Updates the allowlist status of a destination chain for transactions.
	/// @notice This function can only be called by the owner.
	/// @param _destinationChainSelector The selector of the destination chain to be updated.
	/// @param allowed The allowlist status to be set for the destination chain.
	function allowlistDestinationChain(
		uint64 _destinationChainSelector,
		bool allowed
	) external onlyRole(CCIP_OPERATOR_ROLE) {
		ccips().allowlistedDestinationChains[
			_destinationChainSelector
		] = allowed;
	}

	/// @dev Updates the allowlist status of a source chain
	/// @notice This function can only be called by the owner.
	/// @param _sourceChainSelector The selector of the source chain to be updated.
	/// @param allowed The allowlist status to be set for the source chain.
	function allowlistSourceChain(
		uint64 _sourceChainSelector,
		bool allowed
	) external onlyRole(CCIP_OPERATOR_ROLE) {
		ccips().allowlistedSourceChains[_sourceChainSelector] = allowed;
	}

	/// @dev Updates the allowlist status of a sender for transactions.
	/// @notice This function can only be called by the owner.
	/// @param _sender The address of the sender to be updated.
	/// @param allowed The allowlist status to be set for the sender.
	function allowlistSender(
		address _sender,
		bool allowed
	) external onlyRole(CCIP_OPERATOR_ROLE) {
		ccips().allowlistedSenders[_sender] = allowed;
	}

	/// @notice Return the current router
	/// @return i_router address
	function getRouter() public view returns (address) {
		return _getRouter();
	}

	function _ccipReceive(
		Client.Any2EVMMessage memory message
	) internal override {
		(bool success, ) = address(this).call(message.data);
		require(success);
		emit MintCallSuccessfull();
	}

	// ---------------------------- SENDING MESSAGES ------------------------------- //

	/// @notice Sends data and transfer tokens to receiver on the destination chain.
	/// @notice Pay for fees in LINK.
	/// @dev Assumes your contract has sufficient LINK to pay for CCIP fees.
	/// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
	/// @param _receiver The address of the recipient on the destination blockchain.
	/// @param _text The string data to be sent.
	/// @param _token token address.
	/// @param _amount token amount.
	/// @return messageId The ID of the CCIP message that was sent.
	function sendMessagePayLINK(
		uint64 _destinationChainSelector,
		address _receiver,
		string calldata _text,
		address _token,
		uint256 _amount
	)
		external
		onlyAllowlistedDestinationChain(_destinationChainSelector)
		returns (bytes32 messageId)
	{
		// Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
		// address(linkToken) means fees are paid in LINK
		Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
			_receiver,
			_text,
			_token,
			_amount,
			address(ccips().s_linkToken)
		);

		// Initialize a router client instance to interact with cross-chain router
		IRouterClient router = IRouterClient(this.getRouter());

		// Get the fee required to send the CCIP message
		uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

		if (fees > ccips().s_linkToken.balanceOf(address(this)))
			revert NotEnoughBalance(
				ccips().s_linkToken.balanceOf(address(this)),
				fees
			);

		// approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
		ccips().s_linkToken.approve(address(router), fees);

		// approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
		IERC20(_token).approve(address(router), _amount);

		// Send the message through the router and store the returned message ID
		messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

		// Emit an event with message details
		emit MessageSent(
			messageId,
			_destinationChainSelector,
			_receiver,
			_text,
			_token,
			_amount,
			address(ccips().s_linkToken),
			fees
		);

		// Return the message ID
		return messageId;
	}

	/// @notice Sends data and transfer tokens to receiver on the destination chain.
	/// @notice Pay for fees in native gas.
	/// @dev Assumes your contract has sufficient native gas like ETH on Ethereum or MATIC on Polygon.
	/// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
	/// @param _receiver The address of the recipient on the destination blockchain.
	/// @param _text The string data to be sent.
	/// @param _token token address.
	/// @param _amount token amount.
	/// @return messageId The ID of the CCIP message that was sent.
	function sendMessagePayNative(
		uint64 _destinationChainSelector,
		address _receiver,
		string calldata _text,
		address _token,
		uint256 _amount
	)
		external
		onlyAllowlistedDestinationChain(_destinationChainSelector)
		returns (bytes32 messageId)
	{
		// Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
		// address(0) means fees are paid in native gas
		Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
			_receiver,
			_text,
			_token,
			_amount,
			address(0)
		);

		// Initialize a router client instance to interact with cross-chain router
		IRouterClient router = IRouterClient(this.getRouter());

		// Get the fee required to send the CCIP message
		uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

		if (fees > address(this).balance)
			revert NotEnoughBalance(address(this).balance, fees);

		// approve the Router to spend tokens on contract's behalf. It will spend the amount of the given token
		IERC20(_token).approve(address(router), _amount);

		// Send the message through the router and store the returned message ID
		messageId = router.ccipSend{ value: fees }(
			_destinationChainSelector,
			evm2AnyMessage
		);

		// Emit an event with message details
		emit MessageSent(
			messageId,
			_destinationChainSelector,
			_receiver,
			_text,
			_token,
			_amount,
			address(0),
			fees
		);

		// Return the message ID
		return messageId;
	}

	

	// ----------------------------- FAILED MESSAGES ----------------------- //

	/**
	 * @notice Retrieves the IDs of failed messages from the `ccips().s_failedMessages` map.
	 * @dev Iterates over the `ccips().s_failedMessages` map, collecting all keys.
	 * @return ids An array of bytes32 containing the IDs of failed messages from the `ccips().s_failedMessages` map.
	 */
	function getFailedMessagesIds()
		external
		view
		returns (bytes32[] memory ids)
	{
		uint256 length = ccips().s_failedMessages.length();
		bytes32[] memory allKeys = new bytes32[](length);
		for (uint256 i = 0; i < length; i++) {
			(bytes32 key, ) = ccips().s_failedMessages.at(i);
			allKeys[i] = key;
		}
		return allKeys;
	}

	/// @notice Allows the owner to retry a failed message in order to unblock the associated tokens.
	/// @param messageId The unique identifier of the failed message.
	/// @param tokenReceiver The address to which the tokens will be sent.
	/// @dev This function is only callable by the contract owner. It changes the status of the message
	/// from 'failed' to 'resolved' to prevent reentry and multiple retries of the same message.
	function retryFailedMessage(
		bytes32 messageId,
		address tokenReceiver
	) external onlyRole(CCIP_OPERATOR_ROLE) {
		// Check if the message has failed; if not, revert the transaction.
		if (ccips().s_failedMessages.get(messageId) != uint256(ErrorCode.BASIC))
			revert MessageNotFailed(messageId);

		// Set the error code to RESOLVED to disallow reentry and multiple retries of the same failed message.
		ccips().s_failedMessages.set(messageId, uint256(ErrorCode.RESOLVED));

		// Retrieve the content of the failed message.
		Client.Any2EVMMessage memory message = ccips().s_messageContents[
			messageId
		];

		// This example expects one token to have been sent, but you can handle multiple tokens.
		// Transfer the associated tokens to the specified receiver as an escape hatch.
		IERC20(message.destTokenAmounts[0].token).safeTransfer(
			tokenReceiver,
			message.destTokenAmounts[0].amount
		);

		// Emit an event indicating that the message has been recovered.
		emit MessageRecovered(messageId);
	}

	// --------------------------- ADMIN FUNCTIONS ---------------------- //

	/// @notice Fallback function to allow the contract to receive Ether.
	/// @dev This function has no function body, making it a default function for receiving Ether.
	/// It is automatically called when Ether is sent to the contract without any data.
	receive() external payable {}

	/// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
	/// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
	/// It should only be callable by the owner of the contract.
	/// @param _beneficiary The address to which the Ether should be sent.
	function withdraw(
		address _beneficiary
	) public onlyRole(CCIP_OPERATOR_ROLE) {
		// Retrieve the balance of this contract
		uint256 amount = address(this).balance;

		// Revert if there is nothing to withdraw
		if (amount == 0) revert NothingToWithdraw();

		// Attempt to send the funds, capturing the success status and discarding any return data
		(bool sent, ) = _beneficiary.call{ value: amount }("");

		// Revert if the send failed, with information about the attempted transfer
		if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
	}

	/// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
	/// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
	/// @param _beneficiary The address to which the tokens will be sent.
	/// @param _token The contract address of the ERC20 token to be withdrawn.
	function withdrawToken(
		address _beneficiary,
		address _token
	) public onlyRole(CCIP_OPERATOR_ROLE) {
		// Retrieve the balance of this contract
		uint256 amount = IERC20(_token).balanceOf(address(this));

		// Revert if there is nothing to withdraw
		if (amount == 0) revert NothingToWithdraw();

		IERC20(_token).transfer(_beneficiary, amount);
	}
}