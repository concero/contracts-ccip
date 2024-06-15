// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";

import {IConcero} from "./Interfaces/IConcero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {IConceroPool} from "./Interfaces/IConceroPool.sol";

import {Storage} from "./Libraries/Storage.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";

///////////////////////////////
/////////////ERROR/////////////
///////////////////////////////
///@notice error emitted when the new implementation address is invalid
error Orchestrator_InvalidImplementationAddress(address invalidAddress);
///@notice error emitted when a delegatecall fails
error Orchestrator_UnableToCompleteDelegateCall(bytes delegateError);
///@notice error emitted when the input token has Fee on transfers
error Orchestrator_FoTNotAllowedYet();
///@notice error emited when the amount sent if bigger than the specified param
error Orchestrator_InvalidAmount();
///@notice FUNCTIONS ERROR
error Orchestrator_OnlyRouterCanFulfill();
///@notice error emitted when a transaction does not exist
error TxDoesNotExist();
///@notice error emitted when a transaction was already confirmed
error TxAlreadyConfirmed();
///@notice error emitted when a unexpected ID is added
error UnexpectedRequestID(bytes32);

contract Orchestrator is Storage, IFunctionsClient {
  using SafeERC20 for IERC20;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice magic number removal
  uint8 internal constant CL_SRC_RESPONSE_LENGTH = 192;  

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
  ///@notice src chain selector
  uint64 immutable i_chainSelector;
  ///@notice the Chain Index on the getToken function
  Chain immutable i_chainIndex;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice emitted when the Functions router fulfills a request
  event Orchestrator_RequestFulfilled(bytes32 requestId);
  ///@notice emitted when on destination when a TX is validated.
  event TXConfirmed(bytes32 indexed ccipMessageId, address indexed sender, address indexed recipient, uint256 amount, CCIPToken token);
  ///@notice emitted when a Function Request returns an error
  event FunctionsRequestError(bytes32 indexed ccipMessageId, bytes32 requestId, uint8 requestType);
  event TXReleased(bytes32 indexed ccipMessageId, address indexed sender, address indexed recipient, address token, uint256 amount);

  constructor(address _functionsRouter, address _dexSwap, address _concero, address _pool, address _proxy, uint8 _chainIndex, uint64 _chainSelector){
    i_functionsRouter = _functionsRouter;
    i_dexSwap = _dexSwap;
    i_concero = _concero;
    i_pool = _pool;
    i_proxy = _proxy;
    i_chainIndex = Chain(_chainIndex);
    i_chainSelector = _chainSelector;
  }

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

  modifier validateBridgeData(BridgeData calldata _bridgeData) {
    if (_bridgeData.amount == 0) {
      revert Orchestrator_InvalidAmount();
    }
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] calldata _srcSwapData) {
    if (_srcSwapData.length == 0) {
      revert IDexSwap.InvalidSwapData();
    }

    if (_srcSwapData[0].fromToken == address(0)) {
      if (_srcSwapData[0].fromAmount != msg.value) revert IDexSwap.InvalidSwapData();
    }
    _;
  }

  ////////////////////
  ///DELEGATE CALLS///
  ////////////////////
  function swapAndBridge(
    BridgeData calldata _bridgeData,
    IDexSwap.SwapData[] calldata _srcSwapData,
    IDexSwap.SwapData[] calldata _dstSwapData
  ) external payable {
    uint256 amountToSwap = msg.value;

    _swap(_srcSwapData, amountToSwap);

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(abi.encodeWithSelector(IConcero.startBridge.selector, _bridgeData, _dstSwapData));
    if (bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  //@audit adjust the modifier
  function swap(
    IDexSwap.SwapData[] calldata _swapData
  ) external payable tokenAmountSufficiency(_swapData[0].fromToken, _swapData[0].fromAmount) validateSwapData(_swapData) {
    _swap(_swapData, msg.value);
  }

  function bridge(
    BridgeData calldata bridgeData,
    IDexSwap.SwapData[] calldata dstSwapData
  ) external payable tokenAmountSufficiency(getToken(bridgeData.tokenType, i_chainIndex), bridgeData.amount) validateBridgeData(bridgeData) {
    address fromToken = getToken(bridgeData.tokenType, i_chainIndex);

    IERC20(fromToken).safeTransferFrom(msg.sender, address(this), bridgeData.amount);

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(abi.encodeWithSelector(IConcero.startBridge.selector, bridgeData, dstSwapData));
    if (bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err) external {
    if (msg.sender != address(i_functionsRouter)) {
      revert Orchestrator_OnlyRouterCanFulfill();
    }

    Request storage request = s_requests[requestId];

    if (err.length > 0) {
      emit FunctionsRequestError(request.ccipMessageId, requestId, uint8(request.requestType));
      return;
    }

    if (!request.isPending) {
      revert UnexpectedRequestID(requestId);
    }

    request.isPending = false;

    if (request.requestType == RequestType.checkTxSrc) {
      _handleDstFunctionsResponse(request);
    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      _handleSrcFunctionsResponse(response);
    }

    emit Orchestrator_RequestFulfilled(requestId);
  }

  //////////////////////////
  /// INTERNAL FUNCTIONS ///
  //////////////////////////
  function _swap(IDexSwap.SwapData[] memory swapData, uint256 nativeAmount) internal returns (uint256 amountReceived) {
    address fromToken = swapData[0].fromToken;
    uint256 fromAmount = swapData[0].fromAmount;

    if (fromToken != address(0)) {
      //TODO: deal with FoT tokens.
      LibConcero.transferFromERC20(fromToken, msg.sender, address(this), fromAmount);

      (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(
        abi.encodeWithSelector(IDexSwap.conceroEntry.selector, swapData, fromAmount -= (fromAmount / CONCERO_FEE_FACTOR))
      );
      if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    } else {
      (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(
        abi.encodeWithSelector(IDexSwap.conceroEntry.selector, swapData, nativeAmount -= (nativeAmount / CONCERO_FEE_FACTOR))
      );
      if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    }
  }

  function _handleDstFunctionsResponse(Request storage request) internal {
    Transaction storage transaction = s_transactions[request.ccipMessageId];

    _confirmTX(request.ccipMessageId, transaction);

    uint256 amount = transaction.amount - getDstTotalFeeInUsdc(transaction.amount);
    address tokenReceived = getToken(transaction.token, i_chainIndex);

    if (tokenReceived == getToken(CCIPToken.bnm, i_chainIndex)) {
      IConceroPool(i_pool).orchestratorLoan(tokenReceived, amount, transaction.recipient);

      emit TXReleased(request.ccipMessageId, transaction.sender, transaction.recipient, tokenReceived, amount);
    } else {
      IConceroPool(i_pool).orchestratorLoan(tokenReceived, amount, address(this));
      
      // (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(
      //   abi.encodeWithSelector(IDexSwap.conceroEntry.selector, amount)
      // );
      // if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    }
  }

  function _handleSrcFunctionsResponse(bytes memory response) internal {
    if (response.length != CL_SRC_RESPONSE_LENGTH) {
      return;
    }

    (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector, uint256 linkUsdcRate, uint256 nativeUsdcRate, uint256 linkNativeRate) = abi.decode(
      response,
      (uint256, uint256, uint256, uint256, uint256, uint256)
    );

    s_lastGasPrices[i_chainSelector] = srcGasPrice;
    s_lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    s_latestLinkUsdcRate = linkUsdcRate;
    s_latestNativeUsdcRate = nativeUsdcRate;
    s_latestLinkNativeRate = linkNativeRate;
  }

  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    if (transaction.sender == address(0)) revert TxDoesNotExist();
    if (transaction.isConfirmed == true) revert TxAlreadyConfirmed();

    transaction.isConfirmed = true;

    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }
}
