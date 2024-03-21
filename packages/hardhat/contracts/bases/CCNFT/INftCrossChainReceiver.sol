// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CCNFTInternal } from "./CCNFTInternal.sol";
import { Client } from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

interface INftCrossChainReceiver {
	error NotEnoughFunds(uint256 balance, uint256 price, address sender);
	error IncorrectNonce(uint256 messageNonce, uint256 currentNonce);
	error IncorrectOption(uint256 option);
	event CCNFTCreated(address indexed owner, uint256 indexed tokenId);

	function ccipReceive(
		Client.Any2EVMMessage calldata any2EvmMessage
	) external;
}
