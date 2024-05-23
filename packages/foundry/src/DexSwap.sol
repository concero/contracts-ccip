//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma abicoder v2;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IRouter} from "@velodrome/contracts/interfaces/IRouter.sol";
import {ISwapRouter02, IV3SwapRouter} from "./Interfaces/ISwapRouter02.sol";

error DexSwap_CallerNotAllowed(address caller);
error DexSwap_EmptyDexData();
error DexSwap_RouterNotAllowed();

contract DexSwap is Ownable{
  using SafeERC20 for IERC20;

  ///////////////////////
  /// DATA STRUCTURES ///
  ///////////////////////
  ///@notice Concero Enum to track DEXes
  enum DexType {
    UniswapV2, //0
    SushiV3Single, //1
    UniswapV3Single, //2
    SushiV3Multi, //3
    UniswapV3Multi, //4
    Aerodrome //5
  }

  ///@notice Concero Struct to track DEX Data
  struct SwapData {
    DexType dexType;
    bytes dexData; //routerAddress + data to do swap
  }

  event DexSwap_OrchestratorContractUpdated(address previousAddress, address orchestrator);
  event DexSwap_NewRouterAdded(address router, uint256 isAllowed);
  event DexSwap_RemovingDust(address receiver, uint256 amount);

  address private s_orchestrator;
  ///@notice mapping to keep track of allowed routers to perform swaps. 1 == Allowed.
  mapping(address router => uint256 isAllowed) public s_routerAllowed;

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier onlyOrchestrator() {
    if (msg.sender != s_orchestrator) revert DexSwap_CallerNotAllowed(msg.sender);
    _;
  }

  /////////////////////////////////////////////////////////////////
  ////////////////////////////FUNCTIONS////////////////////////////
  /////////////////////////////////////////////////////////////////
  constructor(){}

  /**
   * @notice Function to manage the Orchestrator address
   * @param _orchestrator the contract address
   * @dev only the contract owner should be able to call it
   */
  function manageOrchestratorContract(address _orchestrator) external payable onlyOwner {
    address previousAddress = s_orchestrator;

    s_orchestrator = _orchestrator;

    emit DexSwap_OrchestratorContractUpdated(previousAddress, s_orchestrator);
  }

  /**
   * @notice function to manage DEX routers addresses
   * @param _router the address of the router
   * @param _isAllowed 1 == Allowed | Any other value is not allowed.
   */
  function manageRouterAddress(address _router, uint256 _isAllowed) external payable onlyOwner{
    s_routerAllowed[_router] = _isAllowed;

    emit DexSwap_NewRouterAdded(_router, _isAllowed);
  }

  /**
   * @notice function to withdraw any dust that may be stuck in this contract
   * @param _token the address of the token to be withdraw
   * @param _amount the amount of dust to be collected
   */
  function dustCollection(address _token, uint256 _amount) external onlyOwner {

    emit DexSwap_RemovingDust(msg.sender, _amount);

    IERC20(_token).safeTransfer(msg.sender, _amount);
  }

  /**
   * @notice Entry point function for the Orchestrator to take loans
   * @param _swapData a struct array that contains dex informations.
   * @dev only the Orchestrator contract should be able to call this function
   */
  function conceroEntry(SwapData[] memory _swapData) external onlyOrchestrator {
    if (_swapData.length < 1) revert DexSwap_EmptyDexData();

    uint256 swapDataLength = _swapData.length;

    for(uint i; i <swapDataLength; ++i){
      if (_swapData[i].dexType == DexType.UniswapV2) {
        _swapUniV2Like(_swapData[i].dexData);
      } else if (_swapData[i].dexType == DexType.SushiV3Single) {
        _swapSushiV3Single(_swapData[i].dexData);
      } else if (_swapData[i].dexType == DexType.UniswapV3Single) {
        _swapUniV3Single(_swapData[i].dexData);
      } else if (_swapData[i].dexType == DexType.SushiV3Multi) {
        _swapSushiV3Multi(_swapData[i].dexData);
      } else if (_swapData[i].dexType == DexType.UniswapV3Multi) {
        _swapUniV3Multi(_swapData[i].dexData);
      } else if (_swapData[i].dexType == DexType.Aerodrome) {
        _swapDrome(_swapData[i].dexData);
      }
    }
  }

  /**
   * @notice Function to execute swap accordingly to UniswapV2
   * @param _dexData the enconded swap data
   * @dev This function also accept FoT tokens
   * @dev This function can execute single or multi hop swaps
   */
  function _swapUniV2Like(bytes memory _dexData) private {

    (address routerAddress, uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) = abi.decode(
      _dexData,
      (address, uint256, uint256, address[], address, uint256)
    );
    
    if(s_routerAllowed[routerAddress] != 1) revert DexSwap_RouterNotAllowed();

    uint256 balanceBefore = IERC20(path[0]).balanceOf(address(this));

    IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

    uint256 balanceAfter = IERC20(path[0]).balanceOf(address(this));

    if((balanceAfter - balanceBefore) == amountIn){
      IERC20(path[0]).approve(routerAddress, amountIn);

      IUniswapV2Router02(routerAddress).swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    } else {
      uint256 amount = balanceAfter - balanceBefore;

      IERC20(path[0]).approve(routerAddress, amount);

      IUniswapV2Router02(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, amountOutMin, path, to, deadline);
    }
  }

  /**
   * @notice Function to execute swap
   * @param _dexData the enconded swap data
   * @dev This function can execute swap in any protocol compatible with UniV3 that implements the ISwapRouter
   */
  function _swapSushiV3Single(bytes memory _dexData) private {

    (
      address routerAddress,
      address tokenIn,
      address tokenOut,
      uint24 fee,
      address recipient,
      uint256 deadline,
      uint256 amountIn,
      uint256 amountOutMinimum,
      uint160 sqrtPriceLimitX96
    ) = abi.decode(_dexData, (address, address, address, uint24, address, uint256, uint256, uint256, uint160));

    if(s_routerAllowed[routerAddress] != 1) revert DexSwap_RouterNotAllowed();
    
    TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

    ISwapRouter.ExactInputSingleParams memory dex = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: fee,
      recipient: recipient,
      deadline: deadline,
      amountIn: amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    TransferHelper.safeApprove(tokenIn, routerAddress, amountIn);

    ISwapRouter(routerAddress).exactInputSingle(dex);
  }

  /**
   * @notice UniswapV3 function that executes single hop swaps
   * @param _dexData the enconded swap data
   * @dev This function can execute swap in any protocol compatible with UniV3 that implements the IV3SwapRouter
   */
  function _swapUniV3Single(bytes memory _dexData) private {

    (
      address routerAddress,
      address tokenIn,
      address tokenOut,
      uint24 fee,
      address recipient,
      uint256 amountIn,
      uint256 amountOutMinimum,
      uint160 sqrtPriceLimitX96
    ) = abi.decode(_dexData, (address, address, address, uint24, address, uint256, uint256, uint160));

    if(s_routerAllowed[routerAddress] != 1) revert DexSwap_RouterNotAllowed();
    
    TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

    IV3SwapRouter.ExactInputSingleParams memory dex = IV3SwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: tokenOut,
      fee: fee,
      recipient: recipient,
      amountIn: amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: sqrtPriceLimitX96
    });

    TransferHelper.safeApprove(tokenIn, routerAddress, amountIn);

    ISwapRouter02(routerAddress).exactInputSingle(dex);
  }

  /**
   * @notice SushiSwapV3 function that executes multi hop swaps
   * @param _dexData the enconded swap data
   * @dev This function can execute swap in any protocol compatible with ISwapRouter
   */
  function _swapSushiV3Multi(bytes memory _dexData) private returns(uint256 _amountOut){
    
    (address routerAddress,
    address tokenIn,
    bytes memory path,
    address recipient,
    uint256 deadline,
    uint256 amountIn,
    uint256 amountOutMinimum) = abi.decode(_dexData,(address,address,bytes,address,uint256,uint256,uint256));
  
    if(s_routerAllowed[routerAddress] != 1) revert DexSwap_RouterNotAllowed();

    TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

    ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
      path: path, 
      recipient: recipient,
      deadline: deadline,
      amountIn: amountIn, 
      amountOutMinimum: amountOutMinimum
    });

    TransferHelper.safeApprove(tokenIn, routerAddress, amountIn);

    _amountOut = ISwapRouter(routerAddress).exactInput(params);
  }

  /**
   * @notice UniswapV3 function that executes multi hop swaps
   * @param _dexData the enconded swap data
   * @dev This function can execute swap in any protocol compatible
   */
  function _swapUniV3Multi(bytes memory _dexData) private returns(uint256 _amountOut){
    
    (
    address routerAddress,
    address tokenIn, // <@
    bytes memory path,
    address recipient,
    uint256 amountIn,
    uint256 amountOutMinimum
    ) = abi.decode(_dexData,(address,address,bytes,address,uint256,uint256));
  
    if(s_routerAllowed[routerAddress] != 1) revert DexSwap_RouterNotAllowed();

    TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn); // <@

    IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
      path: path, 
      recipient: recipient,
      amountIn: amountIn, 
      amountOutMinimum: amountOutMinimum
    });

    TransferHelper.safeApprove(tokenIn, routerAddress, amountIn); // <@

    _amountOut = ISwapRouter02(routerAddress).exactInput(params);
  }

  /**
   * @notice Function to execute swaps on Aerodrome and Velodrome Protocols
   * @param _dexData the enconded swap data
   * @dev This function accepts regular and Fee on Transfer tokens
   */
  function _swapDrome(bytes memory _dexData) private {
    if (_dexData.length < 1) revert DexSwap_EmptyDexData();

    (address routerAddress,
    uint256 amountIn,
    uint256 amountOutMin,
    IRouter.Route[] memory routes,
    address to,
    uint256 deadline) = abi.decode(_dexData,(address,uint256,uint256,IRouter.Route[],address,uint256));

    if(s_routerAllowed[routerAddress] != 1) revert DexSwap_RouterNotAllowed();

    uint256 balanceBefore = IERC20(routes[0].from).balanceOf(address(this));

    IERC20(routes[0].from).safeTransferFrom(msg.sender, address(this), amountIn);

    uint256 balanceAfter = IERC20(routes[0].from).balanceOf(address(this));

    if((balanceAfter - balanceBefore) == amountIn){
      IERC20(routes[0].from).approve(routerAddress, amountIn);

      IRouter(routerAddress).swapExactTokensForTokens(amountIn, amountOutMin, routes, to, deadline);
    } else {
      uint256 amount = balanceAfter - balanceBefore;

      IERC20(routes[0].from).approve(routerAddress, amount);
      
      IRouter(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, amountOutMin, routes, to, deadline);
    }
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

