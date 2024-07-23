// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IConcero} from "./Interfaces/IConcero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {StorageSetters} from "./Libraries/StorageSetters.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {IOrchestrator, IOrchestratorViewDelegate} from "./Interfaces/IOrchestrator.sol";
import {ConceroCommon} from "./ConceroCommon.sol";
import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON, USDC_AVALANCHE, CHAIN_SELECTOR_ARBITRUM, CHAIN_SELECTOR_BASE, CHAIN_SELECTOR_OPTIMISM, CHAIN_SELECTOR_POLYGON, CHAIN_SELECTOR_AVALANCHE} from "./Constants.sol";

///////////////////////////////
/////////////ERROR/////////////
///////////////////////////////
///@notice error emitted when a delegatecall fails
error Orchestrator_UnableToCompleteDelegateCall(bytes delegateError);
///@notice error emitted when the balance input is smaller than the specified amount param
error Orchestrator_InvalidAmount();
///@notice error emitted when a address non-router calls the `handleOracleFulfillment` function
error Orchestrator_OnlyRouterCanFulfill();
///@notice error emitted when some params of Bridge Data are empty
error Orchestrator_InvalidBridgeData();
///@notice error emitted when an empty swapData is the input
error Orchestrator_InvalidSwapData();
///@notice error emitted when the ether swap data is corrupted
error Orchestrator_InvalidSwapEtherData();
///@notice error emitted when the token to bridge is not USDC
error Orchestrator_InvalidBridgeToken();
///@notice error emitted when the token is not supported
error Orchestrator_ChainNotSupported();

contract Orchestrator is IFunctionsClient, IOrchestrator, ConceroCommon, StorageSetters {
  using SafeERC20 for IERC20;

  ///////////////
  ///CONSTANTS///
  ///////////////
  uint16 internal constant CONCERO_FEE_FACTOR = 1000;

  ///////////////
  ///IMMUTABLE///
  ///////////////
  ///@notice the address of Functions router
  address immutable i_functionsRouter;
  ///@notice variable to store the DexSwap address
  address immutable i_dexSwap;
  ///@notice variable to store the Concero address
  address immutable i_concero;
  ///@notice variable to store the ConceroPool address
  address immutable i_pool;
  ///@notice variable to store the immutable Proxy Address
  address immutable i_proxy;
  ///@notice ID of the deployed chain on getChain() function
  Chain internal immutable i_chainIndex;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice emitted when the Functions router fulfills a request
  event Orchestrator_RequestFulfilled(bytes32 requestId);
  ///@notice emitted if swap successed
  event Orchestrator_SwapSuccess();

  constructor(address _functionsRouter, address _dexSwap, address _concero, address _pool, address _proxy, uint8 _chainIndex) StorageSetters(msg.sender) {
    i_functionsRouter = _functionsRouter;
    i_dexSwap = _dexSwap;
    i_concero = _concero;
    i_pool = _pool;
    i_proxy = _proxy;
    i_chainIndex = Chain(_chainIndex);
  }

  receive() external payable {}

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (token != address(0)) {
      uint256 balance = IERC20(token).balanceOf(msg.sender);
      if (balance < amount) revert Orchestrator_InvalidAmount();
    } else {
      if (msg.value != amount) revert Orchestrator_InvalidAmount();
    }
    _;
  }

  modifier validateBridgeData(BridgeData memory _bridgeData) {
    if (_bridgeData.amount == 0 || _bridgeData.dstChainSelector == 0 || _bridgeData.receiver == address(0)) revert Orchestrator_InvalidBridgeData();
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] calldata _srcSwapData) {
    uint256 swapDataLength = _srcSwapData.length;

    if (swapDataLength == 0 || swapDataLength > 5 || _srcSwapData[0].fromAmount == 0 || _srcSwapData[0].toAmountMin == 0) {
      revert Orchestrator_InvalidSwapData();
    }

    if (_srcSwapData[0].dexType == IDexSwap.DexType.UniswapV2Ether && _srcSwapData[0].fromToken != address(0)) revert Orchestrator_InvalidSwapEtherData();
    _;
  }

  modifier validateDstSwapData(IDexSwap.SwapData[] memory _srcSwapData) {
    uint256 swapDataLength = _srcSwapData.length;

    if (swapDataLength > 0) {
      if (swapDataLength > 5 || _srcSwapData[0].fromAmount == 0 || _srcSwapData[0].toAmountMin == 0) {
        revert Orchestrator_InvalidSwapData();
      }
    }
    _;
  }

  ////////////////////
  ///DELEGATE CALLS///
  ////////////////////

  ////////////////////////
  /////VIEW FUNCTIONS/////
  ////////////////////////

  function getSrcTotalFeeInUsdc(CCIPToken tokenType, uint64 dstChainSelector, uint256 amount) external view returns (uint256) {
    return IOrchestratorViewDelegate(address(this)).getSrcTotalFeeInUsdcViaDelegateCall(tokenType, dstChainSelector, amount);
  }

  function getSrcTotalFeeInUsdcViaDelegateCall(CCIPToken tokenType, uint64 dstChainSelector, uint256 amount) external returns (uint256) {
    (bool success, bytes memory data) = i_concero.delegatecall(
      abi.encodeWithSelector(IConcero.getSrcTotalFeeInUsdc.selector, tokenType, dstChainSelector, amount)
    );

    if (success == false) revert Orchestrator_UnableToCompleteDelegateCall(data);

    return _convertToUSDCDecimals(abi.decode(data, (uint256)));
  }

  function swapAndBridge(
    BridgeData memory bridgeData,
    IDexSwap.SwapData[] calldata srcSwapData,
    IDexSwap.SwapData[] memory dstSwapData
  )
    external
    payable
    tokenAmountSufficiency(srcSwapData[0].fromToken, srcSwapData[0].fromAmount)
    validateSwapData(srcSwapData)
    validateBridgeData(bridgeData)
    validateDstSwapData(dstSwapData)
    nonReentrant
  {
    if (srcSwapData[srcSwapData.length - 1].toToken != getToken(bridgeData.tokenType, i_chainIndex)) revert Orchestrator_InvalidSwapData();

    {
      //Swap -> money come back to this contract
      uint256 amountReceivedFromSwap = _swap(srcSwapData, 0, false, address(this));

      bridgeData.amount = amountReceivedFromSwap;

      if (dstSwapData.length > 0) {
        dstSwapData[0].fromAmount = amountReceivedFromSwap;
        dstSwapData[0].fromToken = _getDestinationTokenAddress(bridgeData.dstChainSelector);
      }
    }

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(abi.encodeWithSelector(IConcero.startBridge.selector, bridgeData, dstSwapData));
    if (bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  function swap(
    IDexSwap.SwapData[] calldata _swapData,
    address _receiver
  ) external payable validateSwapData(_swapData) tokenAmountSufficiency(_swapData[0].fromToken, _swapData[0].fromAmount) nonReentrant {
    _swap(_swapData, msg.value, true, _receiver);
  }

  function bridge(
    BridgeData memory bridgeData,
    IDexSwap.SwapData[] memory dstSwapData
  ) external validateBridgeData(bridgeData) validateDstSwapData(dstSwapData) nonReentrant {
    {
      uint256 userBalance = IERC20(getToken(bridgeData.tokenType, i_chainIndex)).balanceOf(msg.sender);
      if (userBalance < bridgeData.amount) revert Orchestrator_InvalidAmount();
    }

    if (dstSwapData.length > 0) {
      dstSwapData[0].fromAmount = bridgeData.amount;
      dstSwapData[0].fromToken = _getDestinationTokenAddress(bridgeData.dstChainSelector);
    }
    address fromToken = getToken(bridgeData.tokenType, i_chainIndex);

    LibConcero.transferFromERC20(fromToken, msg.sender, address(this), bridgeData.amount);

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(abi.encodeWithSelector(IConcero.startBridge.selector, bridgeData, dstSwapData));
    if (bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  function addUnconfirmedTX(
    bytes32 ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    uint64 srcChainSelector,
    CCIPToken token,
    uint256 blockNumber,
    bytes calldata dstSwapData
  ) external onlyMessenger {
    (bool success, bytes memory data) = i_concero.delegatecall(
      abi.encodeWithSelector(IConcero.addUnconfirmedTX.selector, ccipMessageId, sender, recipient, amount, srcChainSelector, token, blockNumber, dstSwapData)
    );
    if (success == false) revert Orchestrator_UnableToCompleteDelegateCall(data);
  }

  function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err) external {
    if (msg.sender != address(i_functionsRouter)) {
      revert Orchestrator_OnlyRouterCanFulfill();
    }

    (bool fulfilled, bytes memory notFulfilled) = i_concero.delegatecall(
      abi.encodeWithSelector(IConcero.fulfillRequestWrapper.selector, requestId, response, err)
    );

    if (fulfilled == false) revert Orchestrator_UnableToCompleteDelegateCall(notFulfilled);

    emit Orchestrator_RequestFulfilled(requestId);
  }

  function withdraw(address recipient, address token, uint256 amount) external payable onlyOwner {
    uint256 balance = LibConcero.getBalance(token, address(this));
    if (balance < amount) revert Orchestrator_InvalidAmount();

    if (token != address(0)) {
      LibConcero.transferERC20(token, amount, recipient);
    } else {
      payable(recipient).transfer(amount);
    }
  }

  //////////////////////////
  /// INTERNAL FUNCTIONS ///
  //////////////////////////
  function _swap(IDexSwap.SwapData[] memory swapData, uint256 _nativeAmount, bool isFeesNeeded, address _receiver) internal returns (uint256) {
    address fromToken = swapData[0].fromToken;
    uint256 fromAmount = swapData[0].fromAmount;
    address toToken = swapData[swapData.length - 1].toToken;

    uint256 toTokenBalanceBefore = LibConcero.getBalance(toToken, address(this));

    if (fromToken != address(0)) {
      LibConcero.transferFromERC20(fromToken, msg.sender, address(this), fromAmount);
      if (isFeesNeeded) swapData[0].fromAmount -= (fromAmount / CONCERO_FEE_FACTOR);
    } else {
      if (isFeesNeeded) swapData[0].fromAmount = _nativeAmount - (_nativeAmount / CONCERO_FEE_FACTOR);
    }

    (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(abi.encodeWithSelector(IDexSwap.conceroEntry.selector, swapData, _receiver));
    if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);

    emit Orchestrator_SwapSuccess();

    uint256 toTokenBalanceAfter = LibConcero.getBalance(toToken, address(this));
    return toTokenBalanceAfter - toTokenBalanceBefore;
  }

  //TODO: Add new if statements if new chains are added
  function _getDestinationTokenAddress(uint64 _chainSelector) internal pure returns (address _token) {
    if (_chainSelector == CHAIN_SELECTOR_ARBITRUM) {
      _token = USDC_ARBITRUM;
    } else if (_chainSelector == CHAIN_SELECTOR_BASE) {
      _token = USDC_BASE;
    } else if (_chainSelector == CHAIN_SELECTOR_POLYGON) {
      _token = USDC_POLYGON;
    } else if (_chainSelector == CHAIN_SELECTOR_AVALANCHE) {
      _token = USDC_AVALANCHE;
    } else {
      revert Orchestrator_InvalidBridgeToken();
    }
  }

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  function getTransactionsInfo(bytes32 _ccipMessageId) external view returns (Transaction memory transaction) {
    transaction = s_transactions[_ccipMessageId];
  }
}
