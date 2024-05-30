// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IRouter} from "@velodrome/contracts/interfaces/IRouter.sol";
import {ISwapRouter02, IV3SwapRouter} from "../../src/Interfaces/ISwapRouter02.sol";

contract DEXMock2 {
  using SafeERC20 for IERC20;

    address immutable USDC;

    uint256 constant USDC_DECIMALS = 10 ** 6;
    uint256 constant STANDARD_DECIMALS = 10 ** 18;

    event DexMock_Transferred();

    constructor(address _usdc){
        USDC = _usdc;
    }

    //Sushi Single 
    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory _params) external returns(uint256 amount){

        IERC20(_params.tokenIn).safeTransferFrom(msg.sender, address(this), _params.amountIn);

        IERC20(_params.tokenOut).safeTransfer(_params.recipient, _params.amountOutMinimum);

        emit DexMock_Transferred();
    }


    //Sushi & Uniswap Forks V3 Multi//
    function exactInput(ISwapRouter.ExactInputParams calldata _params) external payable returns (uint256 amountOut){

        (address tokenIn, address tokenOut) = abi.decode(_params.path, (address,address));

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), _params.amountIn);

        IERC20(tokenOut).safeTransfer(_params.recipient, _params.amountOutMinimum);
        emit DexMock_Transferred();
    }

    //Uniswap Only V3 Multi//
    function exactInput(ISwapRouter02.ExactInputParams calldata _params) external payable returns(uint256 amountOut){
        (address tokenIn, address tokenOut) = abi.decode(_params.path, (address,address));

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), _params.amountIn);

        IERC20(tokenOut).safeTransfer(_params.recipient, _params.amountOutMinimum);

        emit DexMock_Transferred();
    }

    // _swapDrome
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        IRouter.Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint[] memory amounts){

            IRouter.Route[] memory route = new IRouter.Route[](routes.length);
            route = routes;

            IERC20(route[0].from).safeTransferFrom(msg.sender, address(this), amountIn);

            if(route[0].to == USDC){
                (amountIn * USDC_DECIMALS) / STANDARD_DECIMALS;

                IERC20(USDC).safeTransfer(to, amountOutMin);
            } else {
                IERC20(route[0].to).safeTransfer(to, amountOutMin);
                amountOutMin;
            }
    }

    /// UTILITIES ///

    function depositToken(address _token, uint256 _amount) external {

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(address _token, uint256 _amount) external {

        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}