// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IAccessControl {
	/**
	 * @dev The `account` is missing a role.
	 */
	error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

	/**
	 * @dev The caller of a function is not the expected one.
	 *
	 * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
	 */
	error AccessControlBadConfirmation();

	/**
	 * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
	 *
	 * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
	 * {RoleAdminChanged} not being emitted signaling this.
	 */
	event RoleAdminChanged(
		bytes32 indexed role,
		bytes32 indexed previousAdminRole,
		bytes32 indexed newAdminRole
	);

	/**
	 * @dev Emitted when `account` is granted `role`.
	 *
	 * `sender` is the account that originated the contract call, an admin role
	 * bearer except when using {AccessControl-_setupRole}.
	 */
	event RoleGranted(
		bytes32 indexed role,
		address indexed account,
		address indexed sender
	);

	/**
	 * @dev Emitted when `account` is revoked `role`.
	 *
	 * `sender` is the account that originated the contract call:
	 *   - if using `revokeRole`, it is the admin role bearer
	 *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
	 */
	event RoleRevoked(
		bytes32 indexed role,
		address indexed account,
		address indexed sender
	);
}
