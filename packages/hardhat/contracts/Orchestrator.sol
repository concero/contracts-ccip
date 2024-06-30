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
///@notice error emitted when the balance input is smaller than the specified amount param
error Orchestrator_InvalidAmount();
///@notice error emitted when a address non-router calls the `handleOracleFulfillment` function
error Orchestrator_OnlyRouterCanFulfill();
///@notice error emitted when the amount received is less than the minAmount to bridge
error Orchestrator_FailedToStartBridge(uint256 receivedAmount, uint256 minAmount);
///@notice error emitted when some params of Bridge Data are empty
error Orchestrator_InvalidBridgeData();
///@notice error emitted when an empty swapData is the input
error Orchestrator_InvalidSwapData();
///@notice error emitted when an attempt to withdraw ether fails
error Orchestrator_EtherWithdrawalFailed();
///@notice error emitted when the ether swap data is corrupted
error Orchestrator_InvalidSwapEtherData();

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
  ///@notice ID of the deployed chain on getChain() function
  Chain internal immutable i_chainIndex;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice emitted when the Functions router fulfills a request
  event Orchestrator_RequestFulfilled(bytes32 requestId);
  ///@notice emitted if swap successed
  event Orchestrator_SwapSuccess();
  ///@notice emitted when fees are withdrawn
  event Orchestrator_FeeWithdrawal(address owner, uint256 amount);

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

  modifier validateBridgeData(BridgeData memory _bridgeData) {
    if (_bridgeData.amount == 0 || _bridgeData.dstChainSelector == 0 || _bridgeData.receiver == address(0)) revert Orchestrator_InvalidBridgeData();
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] calldata _srcSwapData) {
    uint256 swapDataLength = _srcSwapData.length;

    if (swapDataLength == 0 || swapDataLength > 5) {
      revert Orchestrator_InvalidSwapData();
    }

    if(_srcSwapData[0].dexType == IDexSwap.DexType.UniswapV2Ether && _srcSwapData[0].fromToken != address(0)) revert Orchestrator_InvalidSwapEtherData();
    _;
  }

  ////////////////////
  ///DELEGATE CALLS///
  ////////////////////
  function swapAndBridge(
    BridgeData memory bridgeData, 
    IDexSwap.SwapData[] calldata srcSwapData, 
    IDexSwap.SwapData[] calldata dstSwapData
  ) external validateBridgeData(bridgeData){
    if (srcSwapData.length == 0) revert Orchestrator_InvalidSwapData();

    //Swap -> money come back to this contract
    uint256 receivedAmount = _swap(srcSwapData, 0, false, address(this));

    bridgeData.amount = receivedAmount;

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(abi.encodeWithSelector(IConcero.startBridge.selector, bridgeData, dstSwapData));
    if (bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  function swap(
    IDexSwap.SwapData[] calldata _swapData,
    address _receiver
  ) external payable validateSwapData(_swapData) tokenAmountSufficiency(_swapData[0].fromToken, _swapData[0].fromAmount)  {
    _swap(_swapData, msg.value, true, _receiver);
  }

  function bridge(
    BridgeData memory bridgeData,
    IDexSwap.SwapData[] calldata dstSwapData
  ) external payable tokenAmountSufficiency(getToken(bridgeData.tokenType, i_chainIndex), bridgeData.amount) validateBridgeData(bridgeData) {
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

  //////////////////////////
  /// EXTERNAL FUNCTIONS ///
  //////////////////////////
  
  /**
   * @notice function to withdraw ether fees
   * @dev owner address will receive the amount
   * @dev can only be called by owner
   */
  function withdrawEtherFee() external onlyOwner {
    uint256 amount = address(this).balance;

    emit Orchestrator_FeeWithdrawal(msg.sender, amount);

    (bool sent, ) = i_owner.call{value: amount}("");
    if (sent == false) revert Orchestrator_EtherWithdrawalFailed();
  }

  /**
   * @notice function to withdraw erc20 fees
   * @param _token the address of the token to be withdraw
   * @dev can only be called by owner
   */
  function withdrawERC20Fee(address _token) external onlyOwner{
    uint256 amount = IERC20(_token).balanceOf(address(this));

    emit Orchestrator_FeeWithdrawal(msg.sender, amount);

    IERC20(_token).safeTransfer(msg.sender, amount);
  }

  //////////////////////////
  /// INTERNAL FUNCTIONS ///
  //////////////////////////
  error DexSwap_InvalidDexData();
  function _swap(IDexSwap.SwapData[] memory swapData, uint256 _nativeAmount, bool isFeesNeeded, address _receiver) internal returns (uint256) {
    address fromToken = swapData[0].fromToken;
    uint256 fromAmount = swapData[0].fromAmount;
    address toToken = swapData[swapData.length - 1].toToken;

    uint256 toTokenBalanceBefore = IERC20(toToken).balanceOf(address(this));

    if (fromToken != address(0)) {
      //TODO: deal with FoT tokens.
      if (isFeesNeeded) swapData[0].fromAmount -= (fromAmount / CONCERO_FEE_FACTOR);
      LibConcero.transferFromERC20(fromToken, msg.sender, address(this), fromAmount);
    } else {
      if (isFeesNeeded) {
        _nativeAmount -= (_nativeAmount / CONCERO_FEE_FACTOR);
      }
    }

    (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(abi.encodeWithSelector(IDexSwap.conceroEntry.selector, swapData, _nativeAmount, _receiver));
    if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);

    emit Orchestrator_SwapSuccess();

    uint256 toTokenBalanceAfter = IERC20(toToken).balanceOf(address(this));
    return toTokenBalanceAfter - toTokenBalanceBefore;
  }
}
