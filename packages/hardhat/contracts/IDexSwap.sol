//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IDexSwap {
  ///@notice Concero Enum to track DEXes
  enum DexType {
    UniswapV2, //0
    SushiV3Single, //1
    UniswapV3Single, //2
    SushiV3Multi, //3
    UniswapV3Multi, //4
    Aerodrome //5
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
    bytes dexData; //routerAddress + data to do swap
  }

  /**
   * @notice Entry point function for the Orchestrator to take loans
   * @param _swapData a struct array that contains dex informations.
   * @dev only the Orchestrator contract should be able to call this function
   */
  function conceroEntry(SwapData[] memory _swapData, uint256 nativeAmount) external payable;
}
