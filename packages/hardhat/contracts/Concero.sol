// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Concero is ConceroCCIP {
  uint256 public immutable CL_FUNCTIONS_FEE_IN_LINK = 500000000000000000; // 0.5 link

  AggregatorV3Interface public linkToSrcNativeTokenPriceFeeds;

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
    address _linkToSrcNativeTokenPriceFeeds
  ) ConceroCCIP(_functionsRouter, _donHostedSecretsVersion, _donId, _donHostedSecretsSlotId, _subscriptionId, _chainSelector, _chainIndex, _link, _ccipRouter) {
    linkToSrcNativeTokenPriceFeeds = AggregatorV3Interface(_linkToSrcNativeTokenPriceFeeds);
  }

  modifier valueSufficiency(uint64 _dstChainSelector) {
    //    if (!isBridge) return;

    // dst chain cl_functions gas fee
    uint256 calldata srcFunctionsGasFee = (750000 * lastGasPrices[chainSelector]);
    uint256 calldata dstFunctionsGasFee = (750000 * lastGasPrices[_dstChainSelector]);

    // cl_functions fee amount
    (, int256 linkToToNativeRate, , , ) = linkToSrcNativeTokenPriceFeeds.latestRoundData();
    uint8 rateDecimals = linkToSrcNativeTokenPriceFeeds.decimals();
    uint256 calldata functionsSrcFeeInNative = (CL_FUNCTIONS_FEE_IN_LINK * (uint256(linkToToNativeRate) * 10 ** (18 - rateDecimals))) / 1 ether;

    if (msg.value < totalFee) {
      revert InsufficientFee();
    }

    _;
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
