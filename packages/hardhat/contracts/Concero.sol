// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {CHAIN_SELECTOR_ARBITRUM, CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON} from "./Constants.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the Messenger receive an address(0)
error InvalidAddress();
///@notice error emitted when the Messenger were set already
error AddressAlreadyAllowlisted();
///@notice error emitted when the Concero Messenger have been removed already
error NotAllowlistedOrAlreadyRemoved();
///@notice error emitted when the token to be swaped has fee on transfers
error Concero_FoTNotAllowedYet();
///@notice error emitted when the input amount is less than the fees
error InsufficientFundsForFees(uint256 amount, uint256 fee);
///@notice error emitted when there is no ERC20 value to withdraw
error NothingToWithdraw();
///@notice error emitted when there is no native value to withdraw
error FailedToWithdrawEth(address owner, address target, uint256 value);
///@notice error emitted when a non orchestrator address call startBridge
error Concero_ItsNotOrchestrator(address caller);

contract Concero is ConceroCCIP {
  using SafeERC20 for IERC20;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  /// @notice event emitted when a CCIP message is sent
  event CCIPSent(bytes32 indexed ccipMessageId, address sender, address recipient, CCIPToken token, uint256 amount, uint64 dstChainSelector);
  /// @notice event emitted when a stuck amount is withdraw
  event Concero_StuckAmountWithdraw(address owner, address token, uint256 amount);

  uint64 private constant HALF_DST_GAS = 750_000;

  constructor(
    FunctionsVariables memory _variables,
    uint64 _chainSelector,
    uint _chainIndex,
    address _link,
    address _ccipRouter,
    JsCodeHashSum memory _jsCodeHashSum,
    bytes32 _ethersHashSum,
    address _dexSwap,
    address _pool,
    address _proxy
  ) ConceroCCIP(_variables, _chainSelector, _chainIndex, _link, _ccipRouter, _jsCodeHashSum, _ethersHashSum, _dexSwap, _pool, _proxy) {
    clfPremiumFees[CHAIN_SELECTOR_ARBITRUM] = 4000000000000000; // 0.004 link | arb
    clfPremiumFees[CHAIN_SELECTOR_BASE] = 2000000000000000; // 0.002 link | base // takes in usd mb price feed needed
    clfPremiumFees[CHAIN_SELECTOR_OPTIMISM] = 2000000000000000; // 0.002 link | opt
    clfPremiumFees[CHAIN_SELECTOR_POLYGON] = 4000000000000000; // 0.004 link | opt
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////

  function startBridge(BridgeData calldata bridgeData, IDexSwap.SwapData[] calldata _dstSwapData) external {
    if (address(this) != i_proxy) revert Concero_ItsNotOrchestrator(msg.sender);

    address fromToken = getToken(bridgeData.tokenType, i_chainIndex);
    uint256 totalSrcFee = getSrcTotalFeeInUsdc(bridgeData.tokenType, bridgeData.dstChainSelector, bridgeData.amount);
    uint256 mockedLpFee = getDstTotalFeeInUsdc(bridgeData.amount);

    if (bridgeData.amount < totalSrcFee + mockedLpFee) {
      revert InsufficientFundsForFees(bridgeData.amount, totalSrcFee);
    }

    uint256 amount = bridgeData.amount - totalSrcFee;
    uint256 actualLpFee = getDstTotalFeeInUsdc(amount);

    bytes32 ccipMessageId = _sendTokenPayLink(bridgeData.dstChainSelector, fromToken, amount, actualLpFee);
    emit CCIPSent(ccipMessageId, msg.sender, bridgeData.receiver, bridgeData.tokenType, amount, bridgeData.dstChainSelector);
    sendUnconfirmedTX(ccipMessageId, msg.sender, bridgeData.receiver, amount, bridgeData.dstChainSelector, bridgeData.tokenType, _dstSwapData);
  }

  /////////////////
  ///VIEW & PURE///
  /////////////////
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
    // @notice cl functions fee
    uint256 functionsFeeInUsdc = getFunctionsFeeInUsdc(dstChainSelector);

    // @notice cl ccip fee
    uint256 ccipFeeInUsdc = getCCIPFeeInUsdc(tokenType, dstChainSelector);

    // @notice concero fee
    uint256 conceroFee = amount / CONCERO_FEE_FACTOR; //@audit 1_000? == 0.1?

    // @notice gas fee
    uint256 messengerDstGasInNative = HALF_DST_GAS * s_lastGasPrices[dstChainSelector];
    uint256 messengerSrcGasInNative = HALF_DST_GAS * s_lastGasPrices[CHAIN_SELECTOR];
    uint256 messengerGasFeeInUsdc = ((messengerDstGasInNative + messengerSrcGasInNative) * s_latestNativeUsdcRate) / 1 ether;

    // @notice: converting to 6 decimals
    return (functionsFeeInUsdc + ccipFeeInUsdc + conceroFee + messengerGasFeeInUsdc) / 1e12;
  }

  function getCCIPFeeInLink(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(getToken(tokenType, i_chainIndex), 1 ether, 0.1 ether, dstChainSelector);
    return i_ccipRouter.getFee(dstChainSelector, evm2AnyMessage);
  }

  function getCCIPFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector) public view returns (uint256) {
    uint256 ccpFeeInLink = getCCIPFeeInLink(tokenType, dstChainSelector);
    return (ccpFeeInLink * uint256(s_latestLinkUsdcRate)) / 1 ether;
  }
}
