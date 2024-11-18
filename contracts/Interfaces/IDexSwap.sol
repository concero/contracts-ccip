// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IDexSwap {
    ///@notice Concero Struct to track DEX Data
    struct SwapData {
        address dexRouter;
        address fromToken;
        uint256 fromAmount;
        address toToken;
        uint256 toAmount;
        uint256 toAmountMin;
        bytes dexData;
    }

    /**
     * @notice Entry point function for the Orchestrator to take loans
     * @param _swapData a struct array that contains dex information.
     * @dev only the Orchestrator contract should be able to call this function
     */
    function entrypoint(
        SwapData[] memory _swapData,
        address _recipient
    ) external payable returns (uint256);
}
