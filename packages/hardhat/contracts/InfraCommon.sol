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
    ///////////////
    ///CONSTANTS///
    ///////////////
    ///@notice removing magic-numbers
    uint256 internal constant APPROVED = 1;
    uint256 internal constant USDC_DECIMALS = 1_000_000; // 10 ** 6
    uint256 internal constant STANDARD_TOKEN_DECIMALS = 1 ether;

    address private immutable i_msgr0;
    address private immutable i_msgr1;
    address private immutable i_msgr2;

    constructor(address[3] memory _messengers) {
        i_msgr0 = _messengers[0];
        i_msgr1 = _messengers[1];
        i_msgr2 = _messengers[2];
    }
    ///////////////
    ///MODIFIERS///
    ///////////////
    /**
     * @notice modifier to check if the caller is the an approved messenger
     */
    modifier onlyMessenger() {
        if (!_isMessenger(msg.sender)) revert NotMessenger(msg.sender);
        _;
    }

    ///////////////////////////
    ///VIEW & PURE FUNCTIONS///
    ///////////////////////////
    /**
     * @notice Function to check for allowed tokens on specific networks
     * @param tokenType The enum flag of the token
     * @param _chainIndex the index of the chain
     */
    function getUSDCAddressByChainIndex(
        IInfraStorage.CCIPToken tokenType,
        IInfraStorage.Chain _chainIndex
    ) internal view returns (address) {
        address[5][2] memory tokens;

        // REMOVE IN PRODUCTION Initialize BNM addresses
        tokens[uint(IInfraStorage.CCIPToken.bnm)][
            uint(IInfraStorage.Chain.arb)
        ] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
        tokens[uint(IInfraStorage.CCIPToken.bnm)][
            uint(IInfraStorage.Chain.base)
        ] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
        tokens[uint(IInfraStorage.CCIPToken.bnm)][
            uint(IInfraStorage.Chain.opt)
        ] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt
        tokens[uint(IInfraStorage.CCIPToken.bnm)][
            uint(IInfraStorage.Chain.pol)
        ] = 0xcab0EF91Bee323d1A617c0a027eE753aFd6997E4; // pol

        // Initialize USDC addresses
        tokens[uint(IInfraStorage.CCIPToken.usdc)][uint(IInfraStorage.Chain.arb)] = block.chainid ==
            42161
            ? USDC_ARBITRUM
            : USDC_ARBITRUM_SEPOLIA;
        tokens[uint(IInfraStorage.CCIPToken.usdc)][uint(IInfraStorage.Chain.base)] = block
            .chainid == 8453
            ? USDC_BASE
            : USDC_BASE_SEPOLIA;
        tokens[uint(IInfraStorage.CCIPToken.usdc)][uint(IInfraStorage.Chain.opt)] = block.chainid ==
            10
            ? USDC_OPTIMISM
            : USDC_OPTIMISM_SEPOLIA;
        tokens[uint(IInfraStorage.CCIPToken.usdc)][uint(IInfraStorage.Chain.pol)] = block.chainid ==
            137
            ? USDC_POLYGON
            : USDC_POLYGON_AMOY;
        tokens[uint(IInfraStorage.CCIPToken.usdc)][uint(IInfraStorage.Chain.avax)] = block
            .chainid == 43114
            ? USDC_AVALANCHE
            : USDC_AVALANCHE;

        if (uint256(tokenType) > tokens.length) revert TokenTypeOutOfBounds();
        if (uint256(_chainIndex) > tokens[uint256(tokenType)].length)
            revert ChainIndexOutOfBounds();

        return tokens[uint256(tokenType)][uint256(_chainIndex)];
    }

    /**
     * @notice Function to check if a caller address is an allowed messenger
     * @param _messenger the address of the caller
     */
    function _isMessenger(address _messenger) internal view returns (bool) {
        return (_messenger == i_msgr0 || _messenger == i_msgr1 || _messenger == i_msgr2);
    }

    //    function _isMessenger(address _messenger) internal pure returns (bool _isMessenger) {
    //        address[] memory messengers = new address[](4);
    //        messengers[0] = 0x11111003F38DfB073C6FeE2F5B35A0e57dAc4715;
    //        messengers[1] = address(0);
    //        messengers[2] = address(0);
    //        messengers[3] = address(0);
    //
    //        for (uint256 i; i < messengers.length; ) {
    //            if (_messenger == messengers[i]) {
    //                return true;
    //            }
    //            unchecked {
    //                ++i;
    //            }
    //        }
    //        return false;
    //    }

    function getWrappedNative() internal view returns (address _wrappedAddress) {
        uint256 chainId = block.chainid;

        if (chainId == CHAIN_ID_AVALANCHE) {
            _wrappedAddress = WRAPPED_NATIVE_AVALANCHE;
        } else if (chainId == CHAIN_ID_ETHEREUM) {
            _wrappedAddress = WRAPPED_NATIVE_ETHEREUM;
        } else if (chainId == CHAIN_ID_ARBITRUM) {
            _wrappedAddress = WRAPPED_NATIVE_ARBITRUM;
        } else if (chainId == CHAIN_ID_BASE) {
            _wrappedAddress = WRAPPED_NATIVE_BASE;
        } else if (chainId == CHAIN_ID_POLYGON) {
            _wrappedAddress = WRAPPED_NATIVE_POLYGON;
        } else {
            revert ChainNotSupported();
        }
    }

    ///////////////////////////
    /////INTERNAL FUNCTIONS////
    ///////////////////////////

    /**
     * @notice Internal function to convert USDC Decimals to LP Decimals
     * @param _amount the amount of USDC
     * @return _adjustedAmount the adjusted amount
     */
    function _convertToUSDCDecimals(uint256 _amount) internal pure returns (uint256) {
        return (_amount * USDC_DECIMALS) / STANDARD_TOKEN_DECIMALS;
    }
}
