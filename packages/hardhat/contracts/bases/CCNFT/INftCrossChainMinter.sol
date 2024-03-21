// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CCNFTInternal } from "./CCNFTInternal.sol";

interface INftCrossChainMinter {
	error NotEnoughFunds(uint256 balance, uint256 price, address sender);
	error IncorrectNonce(uint256 messageNonce, uint256 currentNonce);
	error IncorrectOption(uint256 option);
	event CCNFTCreated(address indexed owner, uint256 indexed tokenId);

	function mintCrossChainPayLINK(
		uint64 _destinationChainSelector,
		address _receiver,
		uint256 _tokenId
	) external returns (bytes32 messageId);

	function mintCrossChainPayNative(
		uint64 _destinationChainSelector,
		address _receiver,
		uint256 _tokenId
	) external returns (bytes32 messageId);
}
