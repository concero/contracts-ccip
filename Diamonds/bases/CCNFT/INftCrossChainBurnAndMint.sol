// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { CCNFTInternal } from "./CCNFTInternal.sol";

interface INftCrossChainBurnAndMint {
	error NotEnoughFunds(uint256 balance, uint256 price, address sender);
	error IncorrectNonce(uint256 messageNonce, uint256 currentNonce);
	error IncorrectOption(uint256 option);
	event CCNFTCreated(address indexed owner, uint256 indexed tokenId);

	function burnAndMintCrossChainPayLINK(
		uint64 _destinationChainSelector,
		address _receiver,
		uint256 _tokenId
	) external returns (bytes32 messageId);

	function burnAndMintCrossChainPayNative(
		uint64 _destinationChainSelector,
		address _receiver,
		uint256 _tokenId
	) external returns (bytes32 messageId);
}
