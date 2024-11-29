// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {InfraStorage} from "./Libraries/InfraStorage.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {InfraCommon} from "./InfraCommon.sol";
import {IWETH} from "./Interfaces/IWETH.sol";

/* ERRORS */
///@notice error emitted when the caller is not allowed
error OnlyProxyContext(address caller);
///@notice error emitted when the swap data is empty
error EmptyDexData();
///@notice error emitted when the router is not allowed
error DexRouterNotAllowed();
///@notice error emitted when the path to swaps is invalid
error InvalidTokenPath();
///@notice error emitted when the DexData is not valid
error InvalidDexData();
error UnwrapWNativeFailed();
///@notice error emitted when the amount is not sufficient
error InsufficientAmount(uint256 amount);
///@notice error emitted when the transfer failed
error TransferFailed();

contract DexSwap is IDexSwap, InfraCommon, InfraStorage {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /* CONSTANT VARIABLES */
    uint256 private constant BASE_CHAIN_ID = 8453;
    uint256 private constant AVAX_CHAIN_ID = 43114;

    /* IMMUTABLE VARIABLES */
    address private immutable i_proxy;

    /* EVENTS */
    event ConceroSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount,
        address receiver
    );

    constructor(address _proxy, address[3] memory _messengers) InfraCommon(_messengers) {
        i_proxy = _proxy;
    }

    function entrypoint(
        IDexSwap.SwapData[] memory _swapData,
        address _recipient
    ) external payable returns (uint256) {
        if (address(this) != i_proxy) revert OnlyProxyContext(address(this));

        uint256 swapDataLength = _swapData.length;
        address dstToken = _swapData[swapDataLength - 1].toToken;
        uint256 recipientBalanceBefore = LibConcero.getBalance(dstToken, _recipient);

        for (uint256 i; i < swapDataLength; ) {
            //seems to be useless
            uint256 preSwapBalance = LibConcero.getBalance(_swapData[i].toToken, address(this));

            _performSwap(_swapData[i]);

            if (i < swapDataLength - 1) {
                if (_swapData[i].toToken != _swapData[i + 1].fromToken) {
                    revert InvalidTokenPath();
                }
                //seems to be useless
                uint256 postSwapBalance = LibConcero.getBalance(
                    _swapData[i].toToken,
                    address(this)
                );
                uint256 remainingBalance = postSwapBalance - preSwapBalance;

                if (remainingBalance < _swapData[i].toAmountMin) {
                    revert InsufficientAmount(remainingBalance);
                }

                _swapData[i + 1].fromAmount = remainingBalance;
            }

            unchecked {
                ++i;
            }
        }

        uint256 recipientBalanceAfter = LibConcero.getBalance(dstToken, _recipient);
        uint256 dstTokenRecieved = recipientBalanceAfter - recipientBalanceBefore;

        emit ConceroSwap(
            _swapData[0].fromToken,
            dstToken,
            _swapData[0].fromAmount,
            dstTokenRecieved,
            _recipient
        );

        return dstTokenRecieved;
    }

    function _performSwap(IDexSwap.SwapData memory _swapData) private {
        if (_swapData.dexData.length == 0) revert EmptyDexData();

        address routerAddress = _swapData.dexRouter;
        if (!s_routerAllowed[routerAddress]) revert DexRouterNotAllowed();

        uint256 fromAmount = _swapData.fromAmount;
        bool isFromNative = _swapData.fromToken == address(0);

        bool success;
        if (isFromNative) {
            (success, ) = routerAddress.call{value: fromAmount}(_swapData.dexData);
        } else {
            IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, fromAmount);
            (success, ) = routerAddress.call(_swapData.dexData);
        }

        if (!success) revert InvalidDexData();
    }

    // function _wrapNative(IDexSwap.SwapData memory _swapData) private {
    //     address wrappedNative = _getWrappedNative();
    //     IWETH(wrappedNative).deposit{value: _swapData.fromAmount}();
    // }

    // function _unwrapWNative(IDexSwap.SwapData memory _swapData, address _recipient) private {
    //     if (_swapData.fromToken != _getWrappedNative()) revert InvalidDexData();

    //     IWETH(_swapData.fromToken).withdraw(_swapData.fromAmount);

    //     (bool sent, ) = _recipient.call{value: _swapData.fromAmount}("");
    //     if (!sent) {
    //         revert UnwrapWNativeFailed();
    //     }
    // }

    /* HELPER FUNCTIONS */
    function _extractTokens(
        bytes memory _path
    ) private pure returns (address _firstToken, address _lastToken) {
        uint256 pathSize = _path.length;

        bytes memory tokenBytes = _path.slice(0, 20);

        assembly {
            _firstToken := mload(add(tokenBytes, 20))
        }

        bytes memory secondTokenBytes = _path.slice(pathSize - 20, 20);

        assembly {
            _lastToken := mload(add(secondTokenBytes, 20))
        }
    }
}
