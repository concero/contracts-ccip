// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Concero is ConceroCCIP {
  uint256 public immutable CL_FUNCTIONS_FEE_IN_LINK = 500000000000000000; // 0.5 link

  AggregatorV3Interface public linkToUsdPriceFeeds;
  AggregatorV3Interface public usdcToUsdPriceFeeds;
  AggregatorV3Interface public nativeToUsdPriceFeeds;

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
    address _linkToUsdPriceFeeds,
    address _usdcToUsdPriceFeeds
  ) ConceroCCIP(_functionsRouter, _donHostedSecretsVersion, _donId, _donHostedSecretsSlotId, _subscriptionId, _chainSelector, _chainIndex, _link, _ccipRouter) {
    linkToUsdPriceFeeds = AggregatorV3Interface(_linkToUsdPriceFeeds);
    usdcToUsdPriceFeeds = AggregatorV3Interface(_usdcToUsdPriceFeeds);
  }

  // fees module
  function getLinkToUsdcRate() public view returns (int256, uint8) {
    (, int256 linkToUsdRate, , , ) = linkToUsdPriceFeeds.latestRoundData();
    (, int256 usdcToUsdRate, , , ) = usdcToUsdPriceFeeds.latestRoundData();

    uint8 decimals = 18;
    int256 linkToUsdcRate = (linkToUsdRate * int256(10 ** decimals)) / usdcToUsdRate;

    return (linkToUsdcRate, decimals);
  }

  function getNativeToUsdcRate() public view returns (int256, uint8) {
    (, int256 nativeToUsdRate, , , ) = nativeToUsdPriceFeeds.latestRoundData();
    (, int256 usdcToUsdRate, , , ) = usdcToUsdPriceFeeds.latestRoundData();

    uint8 decimals = 18;
    int256 linkToUsdcRate = (nativeToUsdRate * int256(10 ** decimals)) / usdcToUsdRate;

    return (linkToUsdcRate, decimals);
  }

  function getSrcTotalFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector, uint256 amount) public view returns (uint256) {
    (int256 linkToUsdcRate, ) = getLinkToUsdcRate();
    (int256 nativeToUsdcRate, ) = getNativeToUsdcRate();

    // TODO: check what to do if rate is negative
    if (linkToUsdcRate < 0) return 0;

    uint256 functionsFeeInUsdc = (CL_FUNCTIONS_FEE_IN_LINK * uint256(linkToUsdcRate)) / 1 ether;

    uint256 ccpFeeInLink = getCCIPFeeInLink(tokenType, dstChainSelector, amount);
    uint256 ccpFeeInUsdc = (ccpFeeInLink * uint256(linkToUsdcRate)) / 1 ether;

    uint256 conceroFeeInUsdc = amount * 0.003;

    uint256 srcFunctionsGasFee = (750000 * lastGasPrices[chainSelector]);
    uint256 dstFunctionsGasFee = (750000 * lastGasPrices[dstChainSelector]);
    uint256 functionsGasFeeInNative = srcFunctionsGasFee + dstFunctionsGasFee;
    uint256 functionsGasFeeInUsdc = (functionsGasFeeInNative * uint256(nativeToUsdcRate)) / 1 ether;

    return functionsFeeInUsdc + ccpFeeInUsdc + conceroFeeInUsdc + functionsGasFeeInUsdc;
  }

  function getDstTotalFeeInUsdc(uint256 amount) public view returns (uint256) {
    return amount * 0.001;
  }

  function getCCIPFeeInLink(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(this), getToken(tokenType), 1 ether, s_linkToken, dstChainSelector);
    IRouterClient router = IRouterClient(this.getRouter());
    return router.getFee(dstChainSelector, evm2AnyMessage);
  }

  function startTransaction(
    address _token,
    CCIPToken _tokenType,
    uint256 _amount,
    uint64 _dstChainSelector,
    address _receiver,
    bytes calldata _swapData
  ) external payable tokenAmountSufficiency(_token, _amount) valueSufficiency(_dstChainSelector) {
    //todo: maybe move to OZ safeTransfer (but research needed)
    bool isOK = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    require(isOK, "Transfer failed");

    bytes32 ccipMessageId = _sendTokenPayLink(_dstChainSelector, _receiver, _token, _amount);
    emit CCIPSent(ccipMessageId, msg.sender, _receiver, _tokenType, _amount, _dstChainSelector);

    sendUnconfirmedTX(ccipMessageId, msg.sender, _receiver, _amount, _dstChainSelector, _tokenType);
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
    IERC20(_token).transfer(_owner, amount);
  }
}
