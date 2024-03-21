// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library AccessControlStorage {
	bytes32 constant ACL_STORAGE_POSITION =
		keccak256("openzeppelin.accesscontrol.storage");

	// AccessControl
	struct RoleData {
		mapping(address account => bool) hasRole;
		bytes32 adminRole;
		address[] admins;
	}

	/// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
	struct AccessControlStorageStruct {
		mapping(bytes32 role => RoleData) _roles;
	}

	function _getAccessControlStorage()
		internal
		pure
		returns (AccessControlStorageStruct storage $)
	{
		bytes32 position = ACL_STORAGE_POSITION;
		assembly {
			$.slot := position
		}
	}
}
