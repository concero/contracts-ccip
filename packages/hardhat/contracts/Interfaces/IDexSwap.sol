//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IDexSwap {
  ///@notice Concero Enum to track DEXes
  enum DexType {
    UniswapV2,
    UniswapV2FoT,
    SushiV3Single,
    UniswapV3Single,
    SushiV3Multi,
    UniswapV3Multi,
    Aerodrome,
    AerodromeFoT,
    UniswapV2Ether
  }

  error InvalidSwapData();

  ///@notice Concero Struct to track DEX Data
  struct SwapData {
    DexType dexType;
    address fromToken;
    uint256 fromAmount;
    address toToken;
    uint256 toAmount;
    uint256 toAmountMin;
    bytes dexData; //routerAddress + data left to do swap
  }

  /**
   * @notice Entry point function for the Orchestrator to take loans
   * @param _swapData a struct array that contains dex information.
   * @dev only the Orchestrator contract should be able to call this function
   */
  function conceroEntry(SwapData[] memory _swapData, uint256 nativeAmount, address _recipient) external payable;
}
