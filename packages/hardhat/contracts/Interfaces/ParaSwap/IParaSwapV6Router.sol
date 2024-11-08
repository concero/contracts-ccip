// SPDX-License-Identifier: SEE LICENSE IN UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IParaSwapV6Router {
    struct GenericData {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 quotedAmount;
        bytes32 metadata;
        address payable beneficiary;
    }

    /// @notice Executes a generic swapExactAmountIn using the given executorData on the given executor
    /// @param executor The address of the executor contract to use
    /// @param swapData Generic data containing the swap information
    /// @param partnerAndFee packed partner address and fee percentage, the first 12 bytes is the feeData and the last
    /// 20 bytes is the partner address
    /// @param permit The permit data
    /// @param executorData The data to execute on the executor
    /// @return receivedAmount The amount of destToken received after fees
    /// @return paraswapShare The share of the fees for Paraswap
    /// @return partnerShare The share of the fees for the partner
    function swapExactAmountIn(
        address executor,
        GenericData calldata swapData,
        uint256 partnerAndFee,
        bytes calldata permit,
        bytes calldata executorData
    )
        external
        payable
        returns (uint256 receivedAmount, uint256 paraswapShare, uint256 partnerShare);
}
