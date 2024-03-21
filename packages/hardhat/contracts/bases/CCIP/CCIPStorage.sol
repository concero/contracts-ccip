//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import { EnumerableMap } from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/utils/structs/EnumerableMap.sol";

library CCIPStorage {
	using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

	bytes32 constant CCIP_STORAGE_POSITION = keccak256("ccip.internal.storage");

	struct CCIPStorageStruct {
		address i_router;
		IERC20 s_linkToken;
		// Mapping to keep track of allowlisted destination chains.
		mapping(uint64 => bool) allowlistedDestinationChains;
		// Mapping to keep track of allowlisted source chains.
		mapping(uint64 => bool) allowlistedSourceChains;
		// Mapping to keep track of allowlisted senders.
		mapping(address => bool) allowlistedSenders;
		// The message contents of failed messages are stored here.
		mapping(bytes32 messageId => Client.Any2EVMMessage contents) s_messageContents;
		// Contains failed messages and their state.
		EnumerableMap.Bytes32ToUintMap s_failedMessages;
	}

	function _getCCIPStorage()
		internal
		pure
		returns (CCIPStorageStruct storage $)
	{
		bytes32 position = CCIP_STORAGE_POSITION;
		assembly {
			$.slot := position
		}
	}
}
