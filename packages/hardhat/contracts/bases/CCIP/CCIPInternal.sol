// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import { CCIPStorage } from "./CCIPStorage.sol";
import { ICCIP } from "./ICCIP.sol";

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
contract CCIPInternal is ICCIP {
	/// @dev only calls from the set router are accepted.
	modifier onlyRouter() {
		if (msg.sender != address(CCIPStorage._getCCIPStorage().i_router))
			revert InvalidRouter(msg.sender);
		_;
	}

	/// @notice Return the current router
	/// @return i_router address
	function _getRouter() internal view returns (address) {
		return address(CCIPStorage._getCCIPStorage().i_router);
	}

	/// @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
	/// @param _destinationChainSelector The selector of the destination chain.
	modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
		if (
			!CCIPStorage._getCCIPStorage().allowlistedDestinationChains[
				_destinationChainSelector
			]
		) revert DestinationChainNotAllowlisted(_destinationChainSelector);
		_;
	}

	/// @dev Modifier that checks if the chain with the given sourceChainSelector is allowlisted and if the sender is allowlisted.
	/// @param _sourceChainSelector The selector of the destination chain.
	/// @param _sender The address of the sender.
	modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
		if (
			!CCIPStorage._getCCIPStorage().allowlistedSourceChains[
				_sourceChainSelector
			]
		) revert SourceChainNotAllowed(_sourceChainSelector);
		if (!CCIPStorage._getCCIPStorage().allowlistedSenders[_sender])
			revert SenderNotAllowed(_sender);
		_;
	}

	/// @dev Modifier to allow only the contract itself to execute a function.
	/// Throws an exception if called by any account other than the contract itself.
	modifier onlySelf() {
		if (msg.sender != address(this)) revert OnlySelf();
		_;
	}

	function _ccipReceive(
		Client.Any2EVMMessage memory message
	) internal virtual {
		(bool success, ) = address(this).call(message.data);
		require(success);
		emit MintCallSuccessfull();
	}

	// -------------------------------- SENDING MESSAGES ------------------------- //

	/// @notice Construct a CCIP message.
	/// @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
	/// @param _receiver The address of the receiver.
	/// @param _text The string data to be sent.
	/// @param _token The token to be transferred.
	/// @param _amount The amount of the token to be transferred.
	/// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
	/// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
	function _buildCCIPMessage(
		address _receiver,
		string calldata _text,
		address _token,
		uint256 _amount,
		address _feeTokenAddress
	) internal pure returns (Client.EVM2AnyMessage memory) {
		// Set the token amounts
		Client.EVMTokenAmount[]
			memory tokenAmounts = new Client.EVMTokenAmount[](1);
		Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
			token: _token,
			amount: _amount
		});
		tokenAmounts[0] = tokenAmount;
		// Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
		Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
			receiver: abi.encode(_receiver), // ABI-encoded receiver address
			data: abi.encode(_text), // ABI-encoded string
			tokenAmounts: tokenAmounts, // The amount and type of token being transferred
			extraArgs: Client._argsToBytes(
				// Additional arguments, setting gas limit
				Client.EVMExtraArgsV1({ gasLimit: 2_000_000 })
			),
			// Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
			feeToken: _feeTokenAddress
		});
		return evm2AnyMessage;
	}
}
