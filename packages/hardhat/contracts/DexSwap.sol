//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {ISwapRouter02, IV3SwapRouter} from "./Interfaces/ISwapRouter02.sol";

import {Storage} from "./Libraries/Storage.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import "./Libraries/LibConcero.sol";

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

contract DexSwap is Storage, IDexSwap {
  using SafeERC20 for IERC20;

  ///////////////
  ///IMMUTABLE///
  ///////////////
  ///@notice Immutable variable to hold proxy address
  address private immutable i_proxy;

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
  constructor(address _proxy, address _owner) Storage(_owner){
    i_proxy = _proxy;
  }

  /**
   * @notice Entry point function for the Orchestrator to take loans
   * @param _swapData a struct array that contains dex information.
   * @dev only the Orchestrator contract should be able to call this function
   */
  function conceroEntry(IDexSwap.SwapData[] memory _swapData, uint256 _amount) external payable {
    if (address(this) != i_proxy) revert DexSwap_ItsNotOrchestrator(address(this));
    if (_swapData.length < 1 || _swapData.length > 5) revert DexSwap_EmptyDexData();

    uint256 swapDataLength = _swapData.length;

    for (uint256 i; i < swapDataLength; ) {
      uint256 previousBalance;
      uint256 postBalance;

      previousBalance = _swapData[i].fromToken == address(0) ? address(this).balance : IERC20(_swapData[i].fromToken).balanceOf(address(this));

      if (_swapData[i].dexType == DexType.UniswapV3Single) {
        _swapUniV3Single(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.SushiV3Single) {
        _swapSushiV3Single(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.UniswapV2) {
        _swapUniV2Like(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.UniswapV2FoT) {
        _swapUniV2LikeFoT(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.SushiV3Multi) {
        _swapSushiV3Multi(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.UniswapV3Multi) {
        _swapUniV3Multi(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.Aerodrome) {
        _swapDrome(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.AerodromeFoT) {
        _swapDromeFoT(_swapData[i]);
      } else if (_swapData[i].dexType == DexType.UniswapV2Ether) {
        _swapEtherOnUniV2Like(_swapData[i], _amount);
      }

      postBalance = _swapData[i].fromToken == address(0) ? address(this).balance : IERC20(_swapData[i].fromToken).balanceOf(address(this));

      if (swapDataLength > 1 && i + 1 <= swapDataLength) {
        uint256 newBalance = postBalance - previousBalance;
        if (_swapData[i + 1].fromAmount < newBalance) {
          _swapData[i + 1].fromAmount = newBalance;
        }
      }

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Function to execute swap accordingly to UniswapV2
   * @param _swapData the encoded swap data
   * @dev This function can execute single or multi hop swaps
   */
  function _swapUniV2Like(IDexSwap.SwapData memory _swapData) private {
    (address routerAddress, address[] memory path, address recipient, uint256 deadline) = abi.decode(_swapData.dexData, (address, address[], address, uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (path[0] != _swapData.fromToken) revert DexSwap_InvalidPath();

    IERC20(path[0]).approve(routerAddress, _swapData.fromAmount);

    IUniswapV2Router02(routerAddress).swapExactTokensForTokens(_swapData.fromAmount, _swapData.toAmountMin, path, recipient, deadline);
  }

  /**
   * @notice Function to execute swap accordingly to UniswapV2
   * @param _swapData the encoded swap data
   * @dev This function accept FoT tokens
   * @dev This function can execute single or multi hop swaps
   */
  function _swapUniV2LikeFoT(IDexSwap.SwapData memory _swapData) private {
    (address routerAddress, address[] memory path, address recipient, uint256 deadline) = abi.decode(_swapData.dexData, (address, address[], address, uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();
    if (path[0] != _swapData.fromToken) revert DexSwap_InvalidPath();

    IERC20(path[0]).approve(routerAddress, _swapData.fromAmount);

    IUniswapV2Router02(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      _swapData.fromAmount,
      _swapData.toAmountMin,
      path,
      recipient,
      deadline
    );
  }

  /**
   * @notice Function to execute swap
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible with UniV3 that implements the ISwapRouter
   */
  function _swapSushiV3Single(IDexSwap.SwapData memory _swapData) private {
    (address routerAddress, uint24 fee, address recipient, uint256 deadline, uint160 sqrtPriceLimitX96) = abi.decode(
      _swapData.dexData,
      (address, uint24, address, uint256, uint160)
    );

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    ISwapRouter.ExactInputSingleParams memory dex = ISwapRouter.ExactInputSingleParams({
      tokenIn: _swapData.fromToken,
      tokenOut: _swapData.toToken,
      fee: fee,
      recipient: recipient,
      deadline: deadline,
      amountIn: _swapData.fromAmount,
      amountOutMinimum: _swapData.toAmountMin,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    TransferHelper.safeApprove(_swapData.fromToken, routerAddress, _swapData.fromAmount);

    ISwapRouter(routerAddress).exactInputSingle(dex);
  }

  /**
   * @notice UniswapV3 function that executes single hop swaps
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible with UniV3 that implements the IV3SwapRouter
   */
  function _swapUniV3Single(IDexSwap.SwapData memory _swapData) private {
    (address routerAddress, uint24 fee, address recipient, uint160 sqrtPriceLimitX96) = abi.decode(_swapData.dexData, (address, uint24, address, uint160));

    if (s_routerAllowed[routerAddress] != APPROVED) {
      revert DexSwap_RouterNotAllowed();
    }

    IV3SwapRouter.ExactInputSingleParams memory dex = IV3SwapRouter.ExactInputSingleParams({
      tokenIn: _swapData.fromToken,
      tokenOut: _swapData.toToken,
      fee: fee,
      recipient: recipient,
      amountIn: _swapData.fromAmount,
      amountOutMinimum: _swapData.toAmountMin,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    TransferHelper.safeApprove(_swapData.fromToken, routerAddress, _swapData.fromAmount);

    ISwapRouter02(routerAddress).exactInputSingle(dex);
  }

  /**
   * @notice SushiSwapV3 function that executes multi hop swaps
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible with ISwapRouter
   */
  function _swapSushiV3Multi(IDexSwap.SwapData memory _swapData) private returns (uint256 _amountOut) {
    (address routerAddress, bytes memory path, address recipient, uint256 deadline) = abi.decode(_swapData.dexData, (address, bytes, address, uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: path,
      recipient: recipient,
      deadline: deadline,
      amountIn: _swapData.fromAmount,
      amountOutMinimum: _swapData.toAmountMin
    });

    TransferHelper.safeApprove(_swapData.fromToken, routerAddress, _swapData.fromAmount);

    _amountOut = ISwapRouter(routerAddress).exactInput(params);
  }

  /**
   * @notice UniswapV3 function that executes multi hop swaps
   * @param _swapData the encoded swap data
   * @dev This function can execute swap in any protocol compatible
   */
  function _swapUniV3Multi(IDexSwap.SwapData memory _swapData) private returns (uint256 _amountOut) {
    (address routerAddress, bytes memory path, address recipient) = abi.decode(_swapData.dexData, (address, bytes, address));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
      path: path,
      recipient: recipient,
      amountIn: _swapData.fromAmount,
      amountOutMinimum: _swapData.toAmountMin
    });

    TransferHelper.safeApprove(_swapData.fromToken, routerAddress, _swapData.fromAmount); // <@

    _amountOut = ISwapRouter02(routerAddress).exactInput(params);
  }

  /**
   * @notice Function to execute swaps on Aerodrome and Velodrome Protocols
   * @param _swapData the encoded swap data
   * @dev This function accepts regular and Fee on Transfer tokens
   */
  function _swapDrome(IDexSwap.SwapData memory _swapData) private {
    if (_swapData.dexData.length < 1) revert DexSwap_EmptyDexData();

    (address routerAddress, IRouter.Route[] memory routes, address recipient, uint256 deadline) = abi.decode(
      _swapData.dexData,
      (address, IRouter.Route[], address, uint256)
    );

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    IERC20(routes[0].from).approve(routerAddress, _swapData.fromAmount);

    IRouter(routerAddress).swapExactTokensForTokens(_swapData.fromAmount, _swapData.toAmountMin, routes, recipient, deadline);
  }

  /**
   * @notice Function to execute swaps on Aerodrome and Velodrome Protocols
   * @param _swapData the encoded swap data
   * @dev This function accepts Fee on Transfer tokens
   */
  function _swapDromeFoT(IDexSwap.SwapData memory _swapData) private {
    if (_swapData.dexData.length < 1) revert DexSwap_EmptyDexData();

    (address routerAddress, IRouter.Route[] memory routes, address recipient, uint256 deadline) = abi.decode(
      _swapData.dexData,
      (address, IRouter.Route[], address, uint256)
    );

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    IERC20(routes[0].from).approve(routerAddress, _swapData.fromAmount);

    IRouter(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(_swapData.fromAmount, _swapData.toAmountMin, routes, recipient, deadline);
  }

  /**
   * @notice This function can be used with any Uniswap forked router
   * @param _swapData the encoded swap data
   * @param _amount the ether amount to swap
   */
  function _swapEtherOnUniV2Like(IDexSwap.SwapData memory _swapData, uint256 _amount) private returns (uint256[] memory amounts) {
    if (_swapData.dexData.length < 1) revert DexSwap_EmptyDexData();

    (address routerAddress, address[] memory path, address recipient, uint256 deadline) = abi.decode(_swapData.dexData, (address, address[], address, uint256));

    if (s_routerAllowed[routerAddress] != APPROVED) revert DexSwap_RouterNotAllowed();

    amounts = IUniswapV2Router02(routerAddress).swapExactETHForTokens{value: _amount}(_swapData.toAmountMin, path, recipient, deadline);
  }

  /**
   * @notice function to withdraw any dust that may be stuck in this contract
   * @param _token the address of the token to be withdraw
   * @param _amount the amount of dust to be collected
   */
  function dustRemoval(address _token, uint256 _amount) external payable onlyOwner {
    emit DexSwap_RemovingDust(msg.sender, _amount);

    IERC20(_token).safeTransfer(msg.sender, _amount);
  }

  /**
   * @notice function to withdraw any dust that may be stuck in this contract
   * @param _receiver the address that will receive the amount
   */
  function dustEtherRemoval(address _receiver) external onlyOwner {
    uint256 amount = address(this).balance;

    (bool sent, ) = _receiver.call{value: amount}("");
    if (sent = false) revert();
  }
}

/** Arbitrum
 * UniswapV2 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24
 * UniswapV3 0xE592427A0AEce92De3Edee1F18E0157C05861564
 * Camelot 0xc873fEcbd354f5A56E00E710B90EF4201db2448d
 * Balancer 0xBA12222222228d8Ba445958a75a0704d566BF2C8
 * Sushi 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
 */

/** Optimism
 * UniswapV2 0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2
 * UniswapV3 0xE592427A0AEce92De3Edee1F18E0157C05861564
 * Balancer 0xBA12222222228d8Ba445958a75a0704d566BF2C8
 * Velodrome 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858
 */

/** Base
 * UniswapV2 0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24
 * UniswapV3 0x2626664c2603336E57B271c5C0b26F421741e481
 * BalancerV2 0xBA12222222228d8Ba445958a75a0704d566BF2C8
 * Aerodrome 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43
 * Sushi 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891
 */
/** TestNet
 * UniswapV2 0x425141165d3DE9FEC831896C016617a52363b687 - Sepolia
 * UniswapV3 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4 - Base Sepolia
 * Camelot 0xc873fEcbd354f5A56E00E710B90EF4201db2448d
 * Balancer 0xBA12222222228d8Ba445958a75a0704d566BF2C8 - Sepolia
 * Sushi 0xeaBcE3E74EF41FB40024a21Cc2ee2F5dDc615791 - Sepolia
 */
