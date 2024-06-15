// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IConcero} from "./Interfaces/IConcero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {StorageSetters} from "./Libraries/StorageSetters.sol";
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

contract Orchestrator is StorageSetters, IFunctionsClient {
  using SafeERC20 for IERC20;

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
  Chain internal immutable i_chainIndex;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice emitted when the Functions router fulfills a request
  event Orchestrator_RequestFulfilled(bytes32 requestId);

  constructor(address _functionsRouter, address _dexSwap, address _concero, address _pool, address _proxy, uint8 _chainIndex) StorageSetters(msg.sender) {
    i_functionsRouter = _functionsRouter;
    i_dexSwap = _dexSwap;
    i_concero = _concero;
    i_pool = _pool;
    i_proxy = _proxy;
    i_chainIndex = Chain(_chainIndex);
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

    (bool fulfilled, bytes memory notFulfilled) = i_concero.delegatecall(
      abi.encodeWithSelector(IConcero.fulfillRequestWrapper.selector, requestId, response, err)
    );

    if (fulfilled == false) revert Orchestrator_UnableToCompleteDelegateCall(notFulfilled);

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
        abi.encodeWithSelector(IDexSwap.conceroEntry.selector, fromAmount -= (fromAmount / CONCERO_FEE_FACTOR), 0)
      );
      if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    } else {
      (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(
        abi.encodeWithSelector(IDexSwap.conceroEntry.selector, swapData, nativeAmount -= (nativeAmount / CONCERO_FEE_FACTOR))
      );
      if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    }
  }
}
