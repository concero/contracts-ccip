// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library CCNFTStorage {
	bytes32 constant CCNFT_STORAGE_POSITION =
		keccak256("diamond.ccnft.storage");

	struct CCNFTStorageStruct {
		string baseURI;
	}

	function _getCCNFTStorage()
		internal
		pure
		returns (CCNFTStorageStruct storage $)
	{
		bytes32 position = CCNFT_STORAGE_POSITION;
		assembly {
			$.slot := position
		}
	}
}
