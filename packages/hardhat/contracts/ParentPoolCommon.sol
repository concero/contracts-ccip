// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {LPToken} from "./LPToken.sol";

error NotParentPoolProxy(address sender);
error NotMessenger(address sender);

contract ParentPoolCommon {
    ///////////////////////////////////////////////////////////
    //////////////////////// VARIABLES ////////////////////////
    ///////////////////////////////////////////////////////////

    ///////////////
    ///CONSTANTS///
    ///////////////

    uint256 internal constant USDC_DECIMALS = 1_000_000; // 10 ** 6
    uint256 internal constant LP_TOKEN_DECIMALS = 1 ether;
    uint256 internal constant ALLOWED = 1;
    uint256 internal constant PRECISION_HANDLER = 10_000_000_000; // 10 ** 10
    uint8 internal constant MAX_DEPOSITS_ON_THE_WAY_COUNT = 150;
    // TODO: change the deadline in production!!!!!!
    //    uint256 private constant WITHDRAW_DEADLINE_SECONDS = 597_600;
    uint256 private constant WITHDRAW_DEADLINE_SECONDS = 60;

    /////////////////
    ////IMMUTABLES///
    /////////////////

    address internal immutable i_parentPoolProxy;
    LPToken internal immutable i_lpToken;
    address internal immutable i_msgr0;
    address internal immutable i_msgr1;
    address internal immutable i_msgr2;

    /**
     * @notice modifier to ensure if the function is being executed in the proxy context.
     */
    modifier onlyProxyContext() {
        if (address(this) != i_parentPoolProxy) {
            revert NotParentPoolProxy(address(this));
        }
        _;
    }

    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        if (!_isMessenger(msg.sender)) revert NotMessenger(msg.sender);
        _;
    }

    constructor(address parentPool, address lpToken, address msg0, address msg1, address msg2) {
        i_parentPoolProxy = parentPool;
        i_lpToken = LPToken(lpToken);
        i_msgr0 = msg0;
        i_msgr1 = msg1;
        i_msgr2 = msg2;
    }

    ////////////////
    /// INTERNAL ///
    ////////////////

    /**
     * @notice Function to check if a caller address is an allowed messenger
     * @param _messenger the address of the caller
     */
    function _isMessenger(address _messenger) internal view returns (bool) {
        return (_messenger == i_msgr0 || _messenger == i_msgr1 || _messenger == i_msgr2);
    }

    /**
     * @notice Internal function to convert USDC Decimals to LP Decimals
     * @param _usdcAmount the amount of USDC
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToLPTokenDecimals(uint256 _usdcAmount) internal pure returns (uint256) {
        return (_usdcAmount * LP_TOKEN_DECIMALS) / USDC_DECIMALS;
    }

    /**
     * @notice Internal function to convert LP Decimals to USDC Decimals
     * @param _lpAmount the amount of LP
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToUSDCTokenDecimals(uint256 _lpAmount) internal pure returns (uint256) {
        return (_lpAmount * USDC_DECIMALS) / LP_TOKEN_DECIMALS;
    }
}
