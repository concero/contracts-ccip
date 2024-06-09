// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConceroCCIP} from "./ConceroCCIP.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IDexSwap} from "./IDexSwap.sol";
import {LibConcero} from "./LibConcero.sol";

contract Concero is ConceroCCIP {
  uint16 private constant CONCERO_FEE_FACTOR = 1000;

  mapping(uint64 => uint256) public clfPremiumFees;

  IDexSwap private dexSwap;

  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint8 _donHostedSecretsSlotId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex,
    address _link,
    address _ccipRouter,
    address _dexSwap,
    JsCodeHashSum memory jsCodeHashSum,
    bytes32 ethersHashSum
  )
    ConceroCCIP(
      _functionsRouter,
      _donHostedSecretsVersion,
      _donId,
      _donHostedSecretsSlotId,
      _subscriptionId,
      _chainSelector,
      _chainIndex,
      _link,
      _ccipRouter,
      jsCodeHashSum,
      ethersHashSum
    )
  {
    dexSwap = IDexSwap(_dexSwap);

    clfPremiumFees[3478487238524512106] = 4000000000000000; // 0.004 link | arb
    clfPremiumFees[10344971235874465080] = 1847290640394088; // 0.0018 link | base // takes in usd mb price feed needed
    clfPremiumFees[5224473277236331295] = 2000000000000000; // 0.002 link | opt
  }

  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (LibConcero.isNativeToken(token)) {
      if (msg.value != amount) revert InvalidAmount();
    } else {
      uint256 balance = LibConcero.getBalance(token, msg.sender);
      if (balance < amount) revert InvalidAmount();
    }

    _;
  }

  modifier validateSwapAndBridgeData(BridgeData calldata bridgeData, IDexSwap.SwapData[] memory srcSwapData) {
    address swapDataToToken = srcSwapData[srcSwapData.length - 1].toToken;
    if (swapDataToToken == getToken(bridgeData.tokenType)) {
      revert InvalidBridgeData();
    }
    _;
  }

  modifier validateBridgeData(BridgeData calldata bridgeData) {
    if (bridgeData.amount == 0) {
      revert InvalidAmount();
    }
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] memory swapData) {
    if (swapData.length == 0) {
      revert IDexSwap.InvalidSwapData();
    }

    if (LibConcero.isNativeToken(swapData[0].fromToken)) {
      if (swapData[0].fromAmount != msg.value) revert IDexSwap.InvalidSwapData();
    }
    _;
  }

  // setters

  function setDexSwap(address _dexSwap) external onlyOwner {
    dexSwap = IDexSwap(_dexSwap);
  }

  function setClfPremiumFees(uint64 _chainSelector, uint256 feeAmount) external onlyOwner {
    //@audit we must limit this amount. If we don't, it Will trigger a lot of red flags in audits.
    uint256 previousValue = clfPremiumFees[_chainSelector];
    clfPremiumFees[_chainSelector] = feeAmount;
    emit CLFPremiumFeeUpdated(_chainSelector, previousValue, feeAmount);
  }

  // fees module

  function getFunctionsFeeInLink(uint64 dstChainSelector) public view returns (uint256) {
    uint256 srcGasPrice = s_lastGasPrices[CHAIN_SELECTOR];
    uint256 dstGasPrice = s_lastGasPrices[dstChainSelector];
    uint256 srsClFeeInLink = clfPremiumFees[CHAIN_SELECTOR] +
      ((srcGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_CALLBACK_GAS_LIMIT)) * s_latestLinkNativeRate) /
      1 ether;
    uint256 dstClFeeInLink = clfPremiumFees[dstChainSelector] +
      ((dstGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_CALLBACK_GAS_LIMIT)) * s_latestLinkNativeRate) /
      1 ether;

    return srsClFeeInLink + dstClFeeInLink;
  }

  function getFunctionsFeeInUsdc(uint64 dstChainSelector) public view returns (uint256) {
    uint256 functionsFeeInLink = getFunctionsFeeInLink(dstChainSelector);
    return (functionsFeeInLink * s_latestLinkUsdcRate) / 1 ether;
  }

  function getSrcTotalFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector, uint256 amount) public view returns (uint256) {
    // cl functions fee
    uint256 functionsFeeInUsdc = getFunctionsFeeInUsdc(dstChainSelector);

    // cl ccip fee
    uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(tokenType, dstChainSelector);

    // concero fee
    uint256 conceroFee = amount / CONCERO_FEE_FACTOR; //@audit 1_000? == 0.1?

    // gas fee
    uint256 functionsGasFeeInNative = (750_000 * s_lastGasPrices[CHAIN_SELECTOR]) + (750_000 * s_lastGasPrices[dstChainSelector]);
    uint256 functionsGasFeeInUsdc = (functionsGasFeeInNative * s_latestNativeUsdcRate) / 1 ether;

    return functionsFeeInUsdc + ccipFeeInUsdc + conceroFee + functionsGasFeeInUsdc;
  }

  function getCCIPFeeInLink(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(getToken(tokenType), 1 ether, 0.1 ether, dstChainSelector);
    return CCIP_ROUTER.getFee(dstChainSelector, evm2AnyMessage);
  }

  function getCCIPFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    uint256 ccpFeeInLink = getCCIPFeeInLink(tokenType, dstChainSelector);
    return (ccpFeeInLink * uint256(s_latestLinkUsdcRate)) / 1 ether;
  }

  function _startBridge(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata dstSwapData) internal {
    address fromToken = getToken(bridgeData.tokenType);
    uint256 totalSrcFee = getSrcTotalFeeInUsdc(bridgeData.tokenType, bridgeData.dstChainSelector, bridgeData.amount);
    uint256 lpFee = bridgeData.amount / CONCERO_FEE_FACTOR;

    if (bridgeData.amount < totalSrcFee + lpFee) {
      revert InsufficientFundsForFees(bridgeData.amount, totalSrcFee);
    }

    uint256 amount = bridgeData.amount - totalSrcFee;
    bytes32 ccipMessageId = _sendTokenPayLink(bridgeData.dstChainSelector, fromToken, amount, lpFee);
    emit CCIPSent(ccipMessageId, msg.sender, bridgeData.receiver, bridgeData.tokenType, amount, bridgeData.dstChainSelector);
    // TODO: pass _dstSwapData to functions
    sendUnconfirmedTX(ccipMessageId, msg.sender, bridgeData.receiver, amount, bridgeData.dstChainSelector, bridgeData.tokenType);
  }

  function _swap(IDexSwap.SwapData[] memory swapData, uint256 nativeAmount, bool isFeeCollected) internal {
    address fromToken = swapData[0].fromToken;

    if (LibConcero.isNativeToken(fromToken)) {
      if (isFeeCollected) {
        nativeAmount -= (nativeAmount / CONCERO_FEE_FACTOR);
        swapData[0].fromAmount -= (swapData[0].fromAmount / CONCERO_FEE_FACTOR);
      }
      dexSwap.conceroEntry{value: nativeAmount}(swapData, nativeAmount);
    } else {
      LibConcero.transferFromERC20(fromToken, msg.sender, address(this), swapData[0].fromAmount);
      if (isFeeCollected) {
        swapData[0].fromAmount -= (swapData[0].fromAmount / CONCERO_FEE_FACTOR);
      }
      // delegate call
      dexSwap.conceroEntry(swapData, nativeAmount);
    }
  }

  function swap(IDexSwap.SwapData[] memory swapData) external payable tokenAmountSufficiency(swapData[0].fromToken, swapData[0].fromAmount) {
    _swap(swapData, msg.value, true);
  }

  function swapAndBridge(
    BridgeData calldata bridgeData,
    IDexSwap.SwapData[] memory srcSwapData,
    IDexSwap.SwapData[] calldata dstSwapData
  )
    external
    payable
    tokenAmountSufficiency(srcSwapData[0].fromToken, srcSwapData[0].fromAmount)
    validateSwapData(srcSwapData)
    validateBridgeData(bridgeData)
    validateSwapAndBridgeData(bridgeData, srcSwapData)
  {
    _swap(srcSwapData, msg.value, false);
    _startBridge(bridgeData, dstSwapData);
  }

  function bridge(
    BridgeData calldata bridgeData,
    IDexSwap.SwapData[] calldata dstSwapData
  ) external payable tokenAmountSufficiency(getToken(bridgeData.tokenType), bridgeData.amount) validateBridgeData(bridgeData) {
    address fromToken = getToken(bridgeData.tokenType);
    LibConcero.transferFromERC20(fromToken, msg.sender, address(this), bridgeData.amount);
    _startBridge(bridgeData, dstSwapData);
  }

  function withdraw(address _owner) public onlyOwner {
    uint256 amount = address(this).balance;
    if (amount == 0) revert NothingToWithdraw();
    (bool sent, ) = _owner.call{value: amount}("");
    if (!sent) revert FailedToWithdrawEth(msg.sender, _owner, amount);
  }

  function withdrawToken(address _owner, address _token) public onlyOwner {
    uint256 amount = LibConcero.getBalance(_token, address(this));
    if (amount == 0) revert NothingToWithdraw();
    LibConcero.transferERC20(_token, amount, _owner);
  }
}
