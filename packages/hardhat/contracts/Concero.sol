// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IDexSwap} from "./IDexSwap.sol";
import {LibConcero} from "./LibConcero.sol";

contract Concero is ConceroCCIP {
  using SafeERC20 for IERC20;

  mapping(uint64 => uint256) public clfPremiumFees;

  AggregatorV3Interface public immutable linkToUsdPriceFeeds;
  AggregatorV3Interface public immutable usdcToUsdPriceFeeds;
  AggregatorV3Interface public immutable nativeToUsdPriceFeeds;
  AggregatorV3Interface public immutable linkToNativePriceFeeds;

  IDexSwap private dexSwap;

  struct PriceFeeds {
    address linkToUsdPriceFeeds;
    address usdcToUsdPriceFeeds;
    address nativeToUsdPriceFeeds;
    address linkToNativePriceFeeds;
  }

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
    PriceFeeds memory priceFeeds,
    JsCodeHashSum memory jsCodeHashSum
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
      jsCodeHashSum
    )
  {
    linkToUsdPriceFeeds = AggregatorV3Interface(priceFeeds.linkToUsdPriceFeeds);
    usdcToUsdPriceFeeds = AggregatorV3Interface(priceFeeds.usdcToUsdPriceFeeds);
    nativeToUsdPriceFeeds = AggregatorV3Interface(priceFeeds.nativeToUsdPriceFeeds);
    linkToNativePriceFeeds = AggregatorV3Interface(priceFeeds.linkToNativePriceFeeds);
    dexSwap = IDexSwap(_dexSwap);

    clfPremiumFees[3478487238524512106] = 4000000000000000; // 0.004 link | arb
    clfPremiumFees[10344971235874465080] = 1847290640394088; // 0.0018 link | base // takes in usd mb price feed needed
    clfPremiumFees[5224473277236331295] = 2000000000000000; // 0.002 link | opt
  }

  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (LibConcero.isNativeToken(token)) {
      if (msg.value >= amount) revert InvalidAmount();
    } else {
      uint256 balance = LibConcero.getBalance(token, msg.sender);
      if (balance < amount) revert InvalidAmount();
    }

    _;
  }

  modifier validateSwapAndBridgeData(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata srcSwapData) {
    address swapDataToToken = srcSwapData[srcSwapData.length - 1].toToken;
    if (swapDataToToken == getToken(bridgeData.tokenType)) {
      revert InvalidBridgeData();
    }
    _;
  }

  modifier validateBridgeData(BridgeData calldata bridgeData) {
    if (bridgeData.amount > 0) {
      revert InvalidAmount();
    }
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] calldata swapData) {
    if (swapData.length > 0) {
      revert IDexSwap.InvalidSwapData();
    }

    if (LibConcero.isNativeToken(swapData[0].fromToken)) {
      if (swapData[0].fromAmount > msg.value) revert IDexSwap.InvalidSwapData();
    }

    _;
  }

  // setters

  function setDexSwap(address _dexSwap) external onlyOwner {
    dexSwap = IDexSwap(_dexSwap);
  }

  // fees module
  function getLinkToUsdcRate() public view returns (int256, uint8) {
    (, int256 linkToUsdRate, , , ) = linkToUsdPriceFeeds.latestRoundData();
    (, int256 usdcToUsdRate, , , ) = usdcToUsdPriceFeeds.latestRoundData();

    uint8 decimals = 18;
    //@audit USDC overflow? Loss of precision?
    int256 linkToUsdcRate = (linkToUsdRate * int256(10 ** decimals)) / usdcToUsdRate;

    return (linkToUsdcRate, decimals);
  }

  function getNativeToUsdcRate() public view returns (int256, uint8) {
    (, int256 nativeToUsdRate, , , ) = nativeToUsdPriceFeeds.latestRoundData();
    (, int256 usdcToUsdRate, , , ) = usdcToUsdPriceFeeds.latestRoundData();

    uint8 decimals = 18;
    //@audit USDC overflow? Loss of precision?
    int256 linkToUsdcRate = (nativeToUsdRate * int256(10 ** decimals)) / usdcToUsdRate;

    return (linkToUsdcRate, decimals);
  }

  function getFunctionsFeeInLink(uint64 dstChainSelector) public view returns (uint256) {
    (, int256 linkToNativeRate, , , ) = linkToNativePriceFeeds.latestRoundData();

    // TODO: check what to do if rate is negative
    if (linkToNativeRate < 0) {
      return 0;
    }

    uint256 srcGasPrice = s_lastGasPrices[CHAIN_SELECTOR];
    uint256 dstGasPrice = s_lastGasPrices[dstChainSelector];
    uint256 srsClFeeInLink = clfPremiumFees[CHAIN_SELECTOR] +
      ((srcGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_CALLBACK_GAS_LIMIT)) * uint256(linkToNativeRate)) /
      1 ether;
    uint256 dstClFeeInLink = clfPremiumFees[dstChainSelector] +
      ((dstGasPrice * (CL_FUNCTIONS_GAS_OVERHEAD + CL_FUNCTIONS_CALLBACK_GAS_LIMIT)) * uint256(linkToNativeRate)) /
      1 ether;

    return srsClFeeInLink + dstClFeeInLink;
  }

  function getFunctionsFeeInUsdc(uint64 dstChainSelector) public view returns (uint256) {
    (int256 linkToUsdcRate, ) = getLinkToUsdcRate();

    // TODO: check what to do if rate is negative
    if (linkToUsdcRate < 0) {
      return 0;
    }

    uint256 functionsFeeInLink = getFunctionsFeeInLink(dstChainSelector);
    return (functionsFeeInLink * uint256(linkToUsdcRate)) / 1 ether; //todo: we're dividing by 18 decimals, not 6 for USDC. this is critical
  }

  function getSrcTotalFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector, uint256 amount) public view returns (uint256) {
    (int256 nativeToUsdcRate, ) = getNativeToUsdcRate();

    // TODO: check what to do if rate is negative
    if (nativeToUsdcRate < 0) {
      return 0;
    }

    // cl functions fee
    uint256 functionsFeeInUsdc = getFunctionsFeeInUsdc(dstChainSelector);

    // cl ccip fee
    uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(tokenType, dstChainSelector);

    // concero fee
    uint256 conceroFee = amount / 1000; //@audit 1_000? == 0.1?

    // gas fee
    uint256 functionsGasFeeInNative = (750_000 * s_lastGasPrices[CHAIN_SELECTOR]) + (750_000 * s_lastGasPrices[dstChainSelector]);
    uint256 functionsGasFeeInUsdc = (functionsGasFeeInNative * uint256(nativeToUsdcRate)) / 1 ether;

    return functionsFeeInUsdc + ccipFeeInUsdc + conceroFee + functionsGasFeeInUsdc;
  }

  function getCCIPFeeInLink(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    // todo: instead of 0.1 ether, pass the actual fee into _buildCCIPMessage()
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(getToken(tokenType), 1 ether, 0.1 ether, dstChainSelector);

    return CCIP_ROUTER.getFee(dstChainSelector, evm2AnyMessage);
  }

  function getCCIPFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    (int256 linkToUsdcRate, ) = getLinkToUsdcRate();

    // TODO: check what to do if rate is negative
    if (linkToUsdcRate < 0) {
      return 0;
    }

    uint256 ccpFeeInLink = getCCIPFeeInLink(tokenType, dstChainSelector);
    return (ccpFeeInLink * uint256(linkToUsdcRate)) / 1 ether;
  }

  function _startBridge(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata dstSwapData) internal {
    address fromToken = getToken(bridgeData.tokenType);
    uint256 totalSrcFee = getSrcTotalFeeInUsdc(bridgeData.tokenType, bridgeData.dstChainSelector, bridgeData.amount);

    if (bridgeData.amount < totalSrcFee) {
      revert InsufficientFundsForFees(bridgeData.amount, totalSrcFee);
    }

    uint256 amount = bridgeData.amount - totalSrcFee;
    //todo: Pass the actual lp_fee instead of  0.1 ether in _sendTokenPayLink()
    bytes32 ccipMessageId = _sendTokenPayLink(bridgeData.dstChainSelector, fromToken, bridgeData.amount, 0.1 ether);
    emit CCIPSent(ccipMessageId, msg.sender, bridgeData.receiver, bridgeData.tokenType, amount, bridgeData.dstChainSelector);
    sendUnconfirmedTX(ccipMessageId, msg.sender, bridgeData.receiver, amount, bridgeData.dstChainSelector, bridgeData.tokenType);
  }

  // setters
  function setClfPremiumFees(uint64 _chainSelector, uint256 feeAmount) external onlyOwner {
    //@audit we must limit this amount. If we don't, it Will trigger a lot of red flags in audits.
    uint256 previousValue = clfPremiumFees[_chainSelector];
    clfPremiumFees[_chainSelector] = feeAmount;

    emit CLFPremiumFeeUpdated(_chainSelector, previousValue, feeAmount);
  }

  function _swap(IDexSwap.SwapData[] calldata swapData, uint256 nativeAmount) internal returns (uint256) {
    address fromToken = swapData[0].fromToken;
    uint256 fromAmount = swapData[0].fromAmount;

    LibConcero.transferFromERC20(fromToken, msg.sender, address(this), fromAmount);

    address toToken = swapData[swapData.length - 1].toToken;
    uint256 toAmountMin = swapData[swapData.length - 1].toAmountMin;

    // TODO: mb move check balance logic only inside swapAndBridge() function
    uint256 balanceBefore = LibConcero.getBalance(toToken, address(dexSwap));
    LibConcero.transferERC20(fromToken, fromAmount, address(dexSwap));
    dexSwap.conceroEntry{value: nativeAmount}(swapData, nativeAmount);
    uint256 balanceAfter = LibConcero.getBalance(toToken, address(dexSwap));

    if ((balanceBefore + toAmountMin) < balanceAfter) {
      revert FundsLost(toToken, balanceBefore, balanceAfter, toAmountMin);
    }

    uint256 amountOut = balanceAfter - balanceBefore;
    return amountOut;
  }

  function swap(IDexSwap.SwapData[] calldata swapData) external payable tokenAmountSufficiency(swapData[0].fromToken, swapData[0].fromAmount) {
    //    uint256 amountOut =
    _swap(swapData, msg.value);
    //    address toToken = swapData[swapData.length - 1].toToken;
    //    LibConcero.transferERC20(toToken, amountOut, msg.sender);
  }

  function swapAndBridge(
    BridgeData calldata bridgeData,
    IDexSwap.SwapData[] calldata srcSwapData,
    IDexSwap.SwapData[] calldata dstSwapData
  )
    external
    payable
    tokenAmountSufficiency(srcSwapData[0].fromToken, srcSwapData[0].fromAmount)
    validateSwapData(srcSwapData)
    validateBridgeData(bridgeData)
    validateSwapAndBridgeData(bridgeData, srcSwapData)
  {
    _swap(srcSwapData, msg.value);
    _startBridge(bridgeData, dstSwapData);
  }

  function bridge(
    BridgeData calldata bridgeData,
    IDexSwap.SwapData[] calldata dstSwapData
  ) external payable tokenAmountSufficiency(getToken(bridgeData.tokenType), bridgeData.amount) validateBridgeData(bridgeData) {
    address fromToken = getToken(bridgeData.tokenType);
    IERC20(fromToken).safeTransferFrom(msg.sender, address(this), bridgeData.amount);
    _startBridge(bridgeData, dstSwapData);
  }

  function withdraw(address _owner) public onlyOwner {
    uint256 amount = address(this).balance;
    if (amount == 0) revert NothingToWithdraw();
    (bool sent, ) = _owner.call{value: amount}("");
    if (!sent) revert FailedToWithdrawEth(msg.sender, _owner, amount);
  }

  function withdrawToken(address _owner, address _token) public onlyOwner {
    uint256 amount = IERC20(_token).balanceOf(address(this));
    if (amount == 0) revert NothingToWithdraw();
    IERC20(_token).safeTransfer(_owner, amount);
  }
}
