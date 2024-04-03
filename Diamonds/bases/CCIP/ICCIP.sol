// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ICCIP {
	// Custom errors to provide more descriptive revert messages.
	error InvalidRouter(address router);
	error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
	error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
	error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
	error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
	error SourceChainNotAllowed(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
	error SenderNotAllowed(address sender); // Used when the sender has not been allowlisted by the contract owner.
	error OnlySelf(); // Used when a function is called outside of the contract itself.
	error ErrorCase(); // Used when simulating a revert during message processing.
	error MessageNotFailed(bytes32 messageId);

	// Example error code, could have many different error codes.
	enum ErrorCode {
		// RESOLVED is first so that the default value is resolved.
		RESOLVED,
		// Could have any number of error codes here.
		BASIC
	}

	// Event emitted when a message is sent to another chain.
	event CrossChainBurnAndMintMessageSent(
		bytes32 indexed messageId, // The unique ID of the CCIP message.
		uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
		address receiver, // The address of the receiver on the destination chain.
		address to, // address receiveing the NFT
		uint256 tokenId, // the tokenId of the NFT being moved.
		address feeToken, // the token address used to pay CCIP fees.
		uint256 fees // The fees paid for sending the message.
	);

	// Event emitted when a message is sent to another chain.
	event CrossChainMintMessageSent(
		bytes32 indexed messageId, // The unique ID of the CCIP message.
		uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
		address receiver, // The address of the receiver on the destination chain.
		address to, // address the NFT was minted to
		uint256 tokenId, // the tokenId of the NFT being moved.
		address feeToken, // the token address used to pay CCIP fees.
		uint256 fees // The fees paid for sending the message.
	);

	// Event emitted when a message is sent to another chain.
	event MessageSent(
		bytes32 indexed messageId, // The unique ID of the CCIP message.
		uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
		address receiver, // The address of the receiver on the destination chain.
		string text, // The text being sent.
		address token, // The token address that was transferred.
		uint256 tokenAmount, // The token amount that was transferred.
		address feeToken, // the token address used to pay CCIP fees.
		uint256 fees // The fees paid for sending the message.
	);

	// Event emitted when a message is received from another chain.
	event MessageReceived(
		bytes32 indexed messageId, // The unique ID of the CCIP message.
		uint64 indexed sourceChainSelector, // The chain selector of the source chain.
		address sender, // The address of the sender from the source chain.
		string text, // The text that was received.
		address token, // The token address that was transferred.
		uint256 tokenAmount // The token amount that was transferred.
	);

	event MessageFailed(bytes32 indexed messageId, bytes reason);
	event MessageRecovered(bytes32 indexed messageId);

	event MintCallSuccessfull();
}
