// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibDiamond } from "./LibDiamond.sol";
import { AccessControlStorage } from "../bases/AccessControl/AccessControlStorage.sol";
import { ERC721Storage } from "../bases/ERC721/ERC721Storage.sol";
import { CCIPStorage } from "../bases/CCIP/CCIPStorage.sol";
import { CCNFTStorage } from "../bases/CCNFT/CCNFTStorage.sol";

struct RootStorage {
	bool isInitialized;
}

contract UseStorage {
	function rs() internal pure returns (RootStorage storage rst) {
		bytes32 position = keccak256(
			abi.encode(uint256(keccak256("blocspace.root.storage")) - 1)
		) & ~bytes32(uint256(0xff));

		assembly {
			rst.slot := position
		}
	}

	function ccnfts()
		internal
		pure
		returns (CCNFTStorage.CCNFTStorageStruct storage)
	{
		return CCNFTStorage._getCCNFTStorage();
	}

	function acl()
		internal
		pure
		returns (AccessControlStorage.AccessControlStorageStruct storage)
	{
		return AccessControlStorage._getAccessControlStorage();
	}

	function erc721s()
		internal
		pure
		returns (ERC721Storage.ERC721StorageStruct storage)
	{
		return ERC721Storage._getERC721Storage();
	}

	function ccips()
		internal
		pure
		returns (CCIPStorage.CCIPStorageStruct storage)
	{
		return CCIPStorage._getCCIPStorage();
	}

	function ds() internal pure returns (LibDiamond.DiamondStorage storage) {
		return LibDiamond.diamondStorage();
	}
}
