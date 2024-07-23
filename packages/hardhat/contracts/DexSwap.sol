//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ISwapRouter as ISushiRouterV3} from "sushiswap-v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {ISwapRouter02, IV3SwapRouter} from "./Interfaces/ISwapRouter02.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {Storage} from "./Libraries/Storage.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {ConceroCommon} from "./ConceroCommon.sol";
import {IPeripheryPayments} from "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";
import {IWETH} from "./Interfaces/IWETH.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the caller is not allowed
error DexSwap_ItsNotOrchestrator(address caller);
///@notice error emitted when the swap data is empty
error DexSwap_EmptyDexData();
///@notice error emitted when the router is not allowed
error DexSwap_RouterNotAllowed();
///@notice error emitted when the path to swaps is invalid
error DexSwap_InvalidPath();
///@notice error emitted if a swapData has invalid tokens
error DexSwap_SwapDataNotChained(address toToken, address fromToken);
///@notice error emitted if a not-owner-address call the function
error DexSwap_CallableOnlyByOwner(address caller, address owner);
///@notice error emitted when the DexData is not valid
error DexSwap_InvalidDexData();
error DexSwap_UnwrapWNativeFailed();

contract DexSwap is IDexSwap, ConceroCommon, Storage {
  using SafeERC20 for IERC20;
  using BytesLib for bytes;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice removing magic-numbers
  uint256 private constant BASE_CHAIN_ID = 8453; //Testnet
  uint256 private constant AVAX_CHAIN_ID = 43114; //Testnet

  ///////////////
  ///IMMUTABLE///
  ///////////////
  address private immutable i_proxy;
  ///@notice immutable variable to hold wEth address

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when the orchestrator address is updated
  event DexSwap_OrchestratorContractUpdated(address previousAddress, address orchestrator);
  ///@notice event emitted when value locked in the contract is removed
  event DexSwap_RemovingDust(address receiver, uint256 amount);

  /////////////////////////////////////////////////////////////////
  ////////////////////////////FUNCTIONS////////////////////////////
  /////////////////////////////////////////////////////////////////
  constructor(address _proxy) {
    i_proxy = _proxy;
  }

  /**
   * @notice Entry point function for the Orchestrator to take loans
   * @param _swapData a struct array that contains dex information.
   * @dev only the Orchestrator contract should be able to call this function
   */
  function conceroEntry(IDexSwap.SwapData[] memory _swapData, address _recipient) external payable {
    if (address(this) != i_proxy) revert DexSwap_ItsNotOrchestrator(address(this));
    uint256 swapDataLength = _swapData.length;

    for (uint256 i; i < swapDataLength; ) {
      if (swapDataLength > 1 && i < swapDataLength - 1) {
        if (_swapData[i].dexType == DexType.UniswapV2Ether && _swapData[i + 1].dexType == DexType.UniswapV2Ether) revert DexSwap_InvalidPath();
      }

      uint256 previousBalance = LibConcero.getBalance(_swapData[i].toToken, address(this));
      address destinationAddress;

      if (i == swapDataLength - 1 && _recipient != address(this)) {
        destinationAddress = _recipient;
      } else {
        destinationAddress = address(this);
      }

      _performSwap(_swapData[i], destinationAddress);

      if (swapDataLength - 1 > i) {
        if (_swapData[i].toToken != _swapData[i + 1].fromToken) {
          revert DexSwap_SwapDataNotChained(_swapData[i].toToken, _swapData[i + 1].fromToken);
        }
      }

      if (i + 1 <= swapDataLength - 1) {
        uint256 postBalance = LibConcero.getBalance(_swapData[i].toToken, address(this));
        uint256 newBalance = postBalance - previousBalance;
        //Remove the second if because it will always be >= than the amountOutMin.
        _swapData[i + 1].fromAmount = newBalance;
      }

      unchecked {
        ++i;
      }
    }
  }

  function _performSwap(IDexSwap.SwapData memory _swapData, address destinationAddress) private {
    DexType dexType = _swapData.dexType;

    if (dexType == DexType.UniswapV3Single) {
      _swapUniV3Single(_swapData, destinationAddress);
    } else if (dexType == DexType.UniswapV3Multi) {
      _swapUniV3Multi(_swapData, destinationAddress);
    } else if (dexType == DexType.WrapNative) {
      _wrapNative(_swapData);
    } else if (dexType == DexType.UnwrapWNative) {
      _unwrapWNative(_swapData, destinationAddress);
    }
  }

  function _wrapNative(IDexSwap.SwapData memory _swapData) private {
    address wrappedNative = getWrappedNative();
    IWETH(wrappedNative).deposit{value: _swapData.fromAmount}();
  }

  function _unwrapWNative(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.fromToken != getWrappedNative()) revert DexSwap_InvalidDexData();

    IWETH(_swapData.fromToken).withdraw(_swapData.fromAmount);

    (bool sent, ) = _recipient.call{value: _swapData.fromAmount}("");
    if (sent == false) {
      revert DexSwap_UnwrapWNativeFailed();
    }
  }

  /**
   * @notice UniswapV3 function that executes single hop swaps
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible with UniV3 that implements the IV3SwapRouter
   */
  function _swapUniV3Single(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, uint24 fee, uint160 sqrtPriceLimitX96, uint256 deadline) = abi.decode(_swapData.dexData, (address, uint24, uint160, uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    if (block.chainid == BASE_CHAIN_ID || block.chainid == AVAX_CHAIN_ID) {
      IV3SwapRouter.ExactInputSingleParams memory dex = IV3SwapRouter.ExactInputSingleParams({
        tokenIn: _swapData.fromToken,
        tokenOut: _swapData.toToken,
        fee: fee,
        recipient: _recipient,
        amountIn: _swapData.fromAmount,
        amountOutMinimum: _swapData.toAmountMin,
        sqrtPriceLimitX96: sqrtPriceLimitX96
      });

      IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
      ISwapRouter02(routerAddress).exactInputSingle(dex);
    } else {
      ISwapRouter.ExactInputSingleParams memory dex = ISwapRouter.ExactInputSingleParams({
        tokenIn: _swapData.fromToken,
        tokenOut: _swapData.toToken,
        fee: fee,
        recipient: _recipient,
        deadline: deadline,
        amountIn: _swapData.fromAmount,
        amountOutMinimum: _swapData.toAmountMin,
        sqrtPriceLimitX96: sqrtPriceLimitX96
      });

      IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
      ISwapRouter(routerAddress).exactInputSingle(dex);
    }
  }

  /**
   * @notice UniswapV3 function that executes multi hop swaps
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible
   */
  function _swapUniV3Multi(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();

    (address routerAddress, bytes memory path, uint256 deadline) = abi.decode(_swapData.dexData, (address, bytes, uint256));
    (address firstToken, address lastToken) = _extractTokens(path);

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (firstToken != _swapData.fromToken || lastToken != _swapData.toToken) revert DexSwap_InvalidPath();

    if (block.chainid == BASE_CHAIN_ID || block.chainid == AVAX_CHAIN_ID) {
      IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
        path: path,
        recipient: _recipient,
        amountIn: _swapData.fromAmount,
        amountOutMinimum: _swapData.toAmountMin
      });

      IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
      ISwapRouter02(routerAddress).exactInput(params);
    } else {
      ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
        path: path,
        recipient: _recipient,
        deadline: deadline,
        amountIn: _swapData.fromAmount,
        amountOutMinimum: _swapData.toAmountMin
      });

      IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);
      ISwapRouter(routerAddress).exactInput(params);
    }
  }

  /**
   * @notice Function to execute swap accordingly to UniswapV2
   * @param _swapData the encoded swap data
   * @dev This function can execute single or multi hop swaps
   */
  function _swapUniV2Like(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, address[] memory path, uint256 deadline) = abi.decode(_swapData.dexData, (address, address[], uint256));
    uint256 numberOfHops = path.length;

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (path[0] != _swapData.fromToken || path[numberOfHops - 1] != _swapData.toToken) revert DexSwap_InvalidPath();

    IERC20(path[0]).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);

    IUniswapV2Router02(routerAddress).swapExactTokensForTokens(_swapData.fromAmount, _swapData.toAmountMin, path, _recipient, deadline);
  }

  /**
   * @notice Function to execute swap accordingly to UniswapV2
   * @param _swapData the encoded swap data
   * @dev This function accept FoT tokens
   * @dev This function can execute single or multi hop swaps
   */
  function _swapUniV2LikeFoT(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, address[] memory path, uint256 deadline) = abi.decode(_swapData.dexData, (address, address[], uint256));
    uint256 numberOfHops = path.length;

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (path[0] != _swapData.fromToken || path[numberOfHops - 1] != _swapData.toToken) revert DexSwap_InvalidPath();

    IERC20(path[0]).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);

    IUniswapV2Router02(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      _swapData.fromAmount,
      _swapData.toAmountMin,
      path,
      _recipient,
      deadline
    );
  }

  /**
   * @notice Function to execute swap
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible with UniV3 that implements the ISwapRouter
   */
  function _swapSushiV3Single(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, uint24 fee, uint256 deadline, uint160 sqrtPriceLimitX96) = abi.decode(_swapData.dexData, (address, uint24, uint256, uint160));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    ISushiRouterV3.ExactInputSingleParams memory dex = ISushiRouterV3.ExactInputSingleParams({
      tokenIn: _swapData.fromToken,
      tokenOut: _swapData.toToken,
      fee: fee,
      recipient: _recipient,
      deadline: deadline,
      amountIn: _swapData.fromAmount,
      amountOutMinimum: _swapData.toAmountMin,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);

    ISushiRouterV3(routerAddress).exactInputSingle(dex);
  }

  /**
   * @notice SushiSwapV3 function that executes multi hop swaps
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible with ISwapRouter
   */
  function _swapSushiV3Multi(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, bytes memory path, uint256 deadline) = abi.decode(_swapData.dexData, (address, bytes, uint256));

    (address firstToken, address lastToken) = _extractTokens(path);

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (firstToken != _swapData.fromToken || lastToken != _swapData.toToken) revert DexSwap_InvalidPath();

    ISushiRouterV3.ExactInputParams memory params = ISushiRouterV3.ExactInputParams({
      path: path,
      recipient: _recipient,
      deadline: deadline,
      amountIn: _swapData.fromAmount,
      amountOutMinimum: _swapData.toAmountMin
    });

    IERC20(_swapData.fromToken).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);

    ISushiRouterV3(routerAddress).exactInput(params);
  }

  /**
   * @notice Function to execute swaps on Aerodrome and Velodrome Protocols
   * @param _swapData the encoded swap data
   * @dev This function accepts regular and Fee on Transfer tokens
   */
  function _swapDrome(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, IRouter.Route[] memory routes, uint256 deadline) = abi.decode(_swapData.dexData, (address, IRouter.Route[], uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (routes[0].from != _swapData.fromToken || routes[routes.length - 1].to != _swapData.toToken) revert DexSwap_InvalidPath();

    IERC20(routes[0].from).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);

    IRouter(routerAddress).swapExactTokensForTokens(_swapData.fromAmount, _swapData.toAmountMin, routes, _recipient, deadline);
  }

  /**
   * @notice Function to execute swaps on Aerodrome and Velodrome Protocols
   * @param _swapData the encoded swap data
   * @dev This function accepts Fee on Transfer tokens
   */
  function _swapDromeFoT(IDexSwap.SwapData memory _swapData, address _recipient) private {
    if (_swapData.dexData.length < APPROVED) revert DexSwap_EmptyDexData();
    (address routerAddress, IRouter.Route[] memory routes, uint256 deadline) = abi.decode(_swapData.dexData, (address, IRouter.Route[], uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (routes[0].from != _swapData.fromToken || routes[routes.length - 1].to != _swapData.toToken) revert DexSwap_InvalidPath();

    IERC20(routes[0].from).safeIncreaseAllowance(routerAddress, _swapData.fromAmount);

    IRouter(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(_swapData.fromAmount, _swapData.toAmountMin, routes, _recipient, deadline);
  }

  ///////////////////////
  /// Helper Function ///
  ///////////////////////
  function _extractTokens(bytes memory _path) private pure returns (address _firstToken, address _lastToken) {
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

/** Arbitrum
 * UniswapV2 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24
 * UniswapV3 0xE592427A0AEce92De3Edee1F18E0157C05861564 //v1
 * SushiV2 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
 * SushiV3 0x8A21F6768C1f8075791D08546Dadf6daA0bE820c
 */

/** Optimism
 * UniswapV2 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2
 * UniswapV3 0xE592427A0AEce92De3Edee1F18E0157C05861564 //v1
 * Velodrome 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858
 * SushiV2 0x2ABf469074dc0b54d793850807E6eb5Faf2625b1
 */

/** Base
 * UniswapV2 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24
 * UniswapV3 0x2626664c2603336E57B271c5C0b26F421741e481 //v2
 * Aerodrome 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43
 * SushiV2 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891
 * SushiV3 0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f
 */
/** Avalanche
 * UniswapV2 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24
 * UniswapV3 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE //v2
 * SushiV2 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
 */
/** Polygon
 * UniswapV2 0xedf6066a2b290C185783862C7F4776A2C8077AD1
 * UniswapV3 0xE592427A0AEce92De3Edee1F18E0157C05861564 //v1
 * SushiV2 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
 * SushiV3 0x0aF89E1620b96170e2a9D0b68fEebb767eD044c3
 */
/** Ethereum
 * UniswapV2 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
 * UniswapV3 0xE592427A0AEce92De3Edee1F18E0157C05861564 //v1
 * SushiV2 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
 */
/** TestNet
 * UniswapV2 0x425141165d3DE9FEC831896C016617a52363b687 - Sepolia
 * UniswapV3 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4 - Base Sepolia
 * Camelot 0xc873fEcbd354f5A56E00E710B90EF4201db2448d
 * Balancer 0xBA12222222228d8Ba445958a75a0704d566BF2C8 - Sepolia
 * Sushi 0xeaBcE3E74EF41FB40024a21Cc2ee2F5dDc615791 - Sepolia
 */
