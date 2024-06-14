// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {ISwapRouter02, IV3SwapRouter} from "../Interfaces/ISwapRouter02.sol";

error DidntReceiveAnyValue();

contract DEXMock {
  using SafeERC20 for IERC20;

    address immutable USDC;

    uint256 constant USDC_DECIMALS = 10 ** 6;
    uint256 constant STANDARD_DECIMALS = 10 ** 18;

    event DexMock_Transferred();

    constructor(address _usdc){
        USDC = _usdc;
    }

    //Sushi & Uniswap Forks V2
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts){

        address[] memory route = new address[](path.length);
        route = path;

        IERC20(route[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        IERC20(route[1]).safeTransfer(to, amountOutMin);
        emit DexMock_Transferred();
    }

    //Uniswap Single
    function exactInputSingle(ISwapRouter02.ExactInputSingleParams memory _params) external returns(uint256 amount){

        IERC20(_params.tokenIn).safeTransferFrom(msg.sender, address(this), _params.amountIn);

        IERC20(_params.tokenOut).safeTransfer(_params.recipient, _params.amountOutMinimum);

        emit DexMock_Transferred();
    }

    
    //Sushi & Uniswap Forks V3 Multi//
    // function exactInput(ISwapRouter.ExactInputParams calldata _params) external payable returns (uint256 amountOut){

    //     (address tokenIn, address tokenOut) = abi.decode(_params.path, (address,address));

    //     IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), _params.amountIn);

    //     IERC20(tokenOut).safeTransfer(_params.recipient, _params.amountOutMinimum);
    //     emit DexMock_Transferred();
    // }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts){
        address[] memory route = new address[](path.length);
        route = path;

        if(msg.value < 1) revert DidntReceiveAnyValue();

        IERC20(route[1]).safeTransfer(to, amountOutMin);
        emit DexMock_Transferred();
    }

    /// UTILITIES ///

    function depositToken(address _token, uint256 _amount) external {

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(address _token, uint256 _amount) external {

        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}