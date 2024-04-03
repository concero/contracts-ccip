// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library ERC721Storage {
	bytes32 constant ERC721_STORAGE_POSITION =
		keccak256("openzeppelin.erc721.storage");

	struct ERC721StorageStruct {
		// Token name
		string _name;
		// Token symbol
		string _symbol;
		mapping(uint256 tokenId => address) _owners;
		mapping(address owner => uint256) _balances;
		mapping(uint256 tokenId => address) _tokenApprovals;
		mapping(address owner => mapping(address operator => bool)) _operatorApprovals;
	}

	function _getERC721Storage()
		internal
		pure
		returns (ERC721StorageStruct storage $)
	{
		bytes32 position = ERC721_STORAGE_POSITION;
		assembly {
			$.slot := position
		}
	}
}
