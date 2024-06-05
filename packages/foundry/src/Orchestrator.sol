// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";

import {IConcero} from "./Interfaces/IConcero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {Storage} from "./Libraries/Storage.sol";

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

contract Orchestrator is Storage, IFunctionsClient {
  using SafeERC20 for IERC20;

  ///////////////
  ///IMMUTABLE///
  ///////////////
  ///@notice the address of Functions router
  address immutable i_router;
  ///@notice The address of messenger wallet who performs specific calls
  address immutable i_messenger;
  ///@notice variable to store the DexSwap address
  address immutable i_dexSwap;
  ///@notice variable to store the Concero address
  address immutable i_concero;
  ///@notice variable to store the ConceroPool address
  address immutable i_pool;
  ///@notice variable to store the immutable Proxy Address
  address immutable i_proxy;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice emitted when the Functions router fulfills a request
  event Orchestrator_RequestFulfilled(bytes32 requestId);

  constructor(address _router,address _messenger, address _dexSwap, address _concero, address _pool, address _proxy) {
    i_router = _router;
    i_messenger = _messenger;
    i_dexSwap = _dexSwap;
    i_concero = _concero;
    i_pool = _pool;
    i_proxy = _proxy;
  }

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (token == address(0)) {
      if (msg.value != amount) revert Orchestrator_InvalidAmount();
    } else {
      uint256 balance = IERC20(token).balanceOf(msg.sender);
      if (balance < amount) revert Orchestrator_InvalidAmount();
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
  )
    external
    payable
  {
    uint256 amountToSwap = msg.value;
    
    _swap(_srcSwapData, amountToSwap);

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(
        abi.encodeWithSelector(
            IConcero.startBridge.selector,
            _bridgeData,
            _dstSwapData
        )
    );
    if(bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  function swap(IDexSwap.SwapData[] calldata _swapData) external payable tokenAmountSufficiency(_swapData[0].fromToken, _swapData[0].fromAmount)
    validateSwapData(_swapData) {

    _swap(_swapData, msg.value);
  }

  function bridge(
    BridgeData calldata bridgeData,
    IDexSwap.SwapData[] calldata dstSwapData
  ) external payable tokenAmountSufficiency(getToken(bridgeData.tokenType, s_chainIndex), bridgeData.amount) validateBridgeData(bridgeData) {

    address fromToken = getToken(bridgeData.tokenType, s_chainIndex);

    IERC20(fromToken).safeTransferFrom(msg.sender, address(this), bridgeData.amount);    
    
    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(
        abi.encodeWithSelector(
            IConcero.startBridge.selector,
            bridgeData,
            dstSwapData
        )
    );

    if(bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }
  
  //////////////////////////
  /// INTERNAL FUNCTIONS ///
  //////////////////////////
  function _swap(IDexSwap.SwapData[] calldata _srcSwapData, uint256 nativeAmount) internal returns (uint256 amountReceived) {
    address fromToken = _srcSwapData[0].fromToken;
    uint256 fromAmount = _srcSwapData[0].fromAmount;

    if(fromToken == address(0)){
        (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(
            abi.encodeWithSelector(
                IDexSwap.conceroEntry.selector,
                _srcSwapData,
                nativeAmount
            )
        );
        if(swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    } else {
        uint256 balanceBefore = IERC20(fromToken).balanceOf(address(this));
        IERC20(fromToken).safeTransferFrom(msg.sender, address(this), fromAmount);
        uint256 balanceAfter = IERC20(fromToken).balanceOf(address(this));

        //TODO: deal with FoT tokens.
        amountReceived = balanceAfter - balanceBefore;

        if(amountReceived != fromAmount) revert Orchestrator_FoTNotAllowedYet();

        (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(
            abi.encodeWithSelector(
                IDexSwap.conceroEntry.selector,
                _srcSwapData,
                nativeAmount
            )
        );
        if(swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    }
  }

  function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err) external {
    if (msg.sender != address(i_router)) {
      revert Orchestrator_OnlyRouterCanFulfill();
    }

    (bool fulfilled, bytes memory notFulfilled) = i_concero.delegatecall(
      abi.encodeWithSelector(
        //@audit I had to create a wrapper to be able to call the final function.
        IConcero.fulfillRequestWrapper.selector,
        requestId,
        response,
        err
      )
    );

    if(fulfilled == false) revert Orchestrator_UnableToCompleteDelegateCall(notFulfilled);

    emit Orchestrator_RequestFulfilled(requestId);
  }
}