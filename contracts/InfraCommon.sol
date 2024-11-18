// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON, USDC_POLYGON_AMOY, USDC_ARBITRUM_SEPOLIA, USDC_BASE_SEPOLIA, USDC_OPTIMISM_SEPOLIA, USDC_AVALANCHE} from "./Constants.sol";
import {CHAIN_ID_AVALANCHE, WRAPPED_NATIVE_AVALANCHE, CHAIN_ID_ETHEREUM, WRAPPED_NATIVE_ETHEREUM, CHAIN_ID_ARBITRUM, WRAPPED_NATIVE_ARBITRUM, CHAIN_ID_BASE, WRAPPED_NATIVE_BASE, CHAIN_ID_POLYGON, WRAPPED_NATIVE_POLYGON} from "./Constants.sol";
import {IInfraStorage} from "./Interfaces/IInfraStorage.sol";

error NotMessenger(address _messenger);
error ChainIndexOutOfBounds();
error TokenTypeOutOfBounds();
error ChainNotSupported();

contract InfraCommon {
    /* CONSTANT VARIABLES */
    uint256 internal constant USDC_DECIMALS = 1_000_000;
    uint256 internal constant STANDARD_TOKEN_DECIMALS = 1 ether;

    /* IMMUTABLE VARIABLES */
    address private immutable i_msgr0;
    address private immutable i_msgr1;
    address private immutable i_msgr2;

    constructor(address[3] memory _messengers) {
        i_msgr0 = _messengers[0];
        i_msgr1 = _messengers[1];
        i_msgr2 = _messengers[2];
    }
    /* MODIFIERS */
    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        if (!_isMessenger(msg.sender)) revert NotMessenger(msg.sender);
        _;
    }

    /* VIEW & PURE FUNCTIONS */
    /**
     * @notice Function to check for allowed tokens on specific networks
     * @param tokenType The enum flag of the token
     * @param _chainIndex the index of the chain
     */

    function _getUSDCAddressByChainIndex(
        IInfraStorage.CCIPToken tokenType,
        IInfraStorage.Chain _chainIndex
    ) internal view returns (address) {
        //mainnet
        if (tokenType == IInfraStorage.CCIPToken.usdc) {
            if (_chainIndex == IInfraStorage.Chain.arb) {
                return block.chainid == 42161 ? USDC_ARBITRUM : USDC_ARBITRUM_SEPOLIA;
            } else if (_chainIndex == IInfraStorage.Chain.base) {
                return block.chainid == 8453 ? USDC_BASE : USDC_BASE_SEPOLIA;
            } else if (_chainIndex == IInfraStorage.Chain.opt) {
                return block.chainid == 10 ? USDC_OPTIMISM : USDC_OPTIMISM_SEPOLIA;
            } else if (_chainIndex == IInfraStorage.Chain.pol) {
                return block.chainid == 137 ? USDC_POLYGON : USDC_POLYGON_AMOY;
            } else if (_chainIndex == IInfraStorage.Chain.avax) {
                return USDC_AVALANCHE;
            } else {
                revert ChainIndexOutOfBounds();
            }
        } else {
            revert TokenTypeOutOfBounds();
        }
    }

    /**
     * @notice Function to check if a caller address is an allowed messenger
     * @param _messenger the address of the caller
     */
    function _isMessenger(address _messenger) internal view returns (bool) {
        return (_messenger == i_msgr0 || _messenger == i_msgr1 || _messenger == i_msgr2);
    }

    function _getWrappedNative() internal view returns (address _wrappedAddress) {
        uint256 chainId = block.chainid;

        if (chainId == CHAIN_ID_ARBITRUM) {
            _wrappedAddress = WRAPPED_NATIVE_ARBITRUM;
        } else if (chainId == CHAIN_ID_BASE) {
            _wrappedAddress = WRAPPED_NATIVE_BASE;
        } else if (chainId == CHAIN_ID_POLYGON) {
            _wrappedAddress = WRAPPED_NATIVE_POLYGON;
        } else if (chainId == CHAIN_ID_ETHEREUM) {
            _wrappedAddress = WRAPPED_NATIVE_ETHEREUM;
        } else if (chainId == CHAIN_ID_AVALANCHE) {
            _wrappedAddress = WRAPPED_NATIVE_AVALANCHE;
        } else {
            revert ChainNotSupported();
        }
    }

    /* INTERNAL FUNCTIONS */
    /**
     * @notice Internal function to convert USDC Decimals to LP Decimals
     * @param amount the amount of USDC
     * @return adjustedAmount the adjusted amount
     */
    function _convertToUSDCDecimals(uint256 amount) internal pure returns (uint256) {
        return (amount * USDC_DECIMALS) / STANDARD_TOKEN_DECIMALS;
    }
}
