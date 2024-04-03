// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import { IAccessControl } from "./IAccessControl.sol";
import { AccessControlStorage } from "./AccessControlStorage.sol";

contract AccessControlInternal is IAccessControl {
	bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
	bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
	bytes32 constant CCIP_OPERATOR_ROLE = keccak256("CCIP_OPERATOR_ROLE");
	/**
	 * @dev Modifier that checks that an account has a specific role. Reverts
	 * with an {AccessControlUnauthorizedAccount} error including the required role.
	 */
	modifier onlyRole(bytes32 role) {
		_checkRole(role);
		_;
	}

	/**
	 * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `msg.sender`
	 * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
	 */
	function _checkRole(bytes32 role) internal view {
		_checkRole(role, msg.sender);
	}

	/**
	 * @dev Returns `true` if `account` has been granted `role`.
	 */
	function _hasRole(
		bytes32 role,
		address account
	) internal view returns (bool) {
		return
			AccessControlStorage
				._getAccessControlStorage()
				._roles[role]
				.hasRole[account];
	}

	/**
	 * @dev Returns the admin role that controls `role`. See {grantRole} and
	 * {revokeRole}.
	 *
	 * To change a role's admin, use {_setRoleAdmin}.
	 */
	function _getRoleAdmin(bytes32 role) internal view returns (bytes32) {
		return
			AccessControlStorage
				._getAccessControlStorage()
				._roles[role]
				.adminRole;
	}

	/**
	 * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
	 * is missing `role`.
	 */
	function _checkRole(bytes32 role, address account) internal view {
		if (!_hasRole(role, account)) {
			revert AccessControlUnauthorizedAccount(account, role);
		}
	}

	/**
	 * @dev Sets `adminRole` as ``role``'s admin role.
	 *
	 * Emits a {RoleAdminChanged} event.
	 */
	function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
		bytes32 previousAdminRole = _getRoleAdmin(role);
		AccessControlStorage
			._getAccessControlStorage()
			._roles[role]
			.adminRole = adminRole;
		emit RoleAdminChanged(role, previousAdminRole, adminRole);
	}

	/**
	 * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
	 *
	 * Internal function without access restriction.
	 *
	 * May emit a {RoleGranted} event.
	 */
	function _grantRole(bytes32 role, address account) internal returns (bool) {
		if (!_hasRole(role, account)) {
			AccessControlStorage
				._getAccessControlStorage()
				._roles[role]
				.hasRole[account] = true;
			emit RoleGranted(role, account, msg.sender);
			return true;
		} else {
			return false;
		}
	}

	/**
	 * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
	 *
	 * Internal function without access restriction.
	 *
	 * May emit a {RoleRevoked} event.
	 */
	function _revokeRole(
		bytes32 role,
		address account
	) internal returns (bool) {
		if (_hasRole(role, account)) {
			AccessControlStorage
				._getAccessControlStorage()
				._roles[role]
				.hasRole[account] = false;
			emit RoleRevoked(role, account, msg.sender);
			return true;
		} else {
			return false;
		}
	}
}
