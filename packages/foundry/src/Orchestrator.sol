// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/upgradeable/contracts/proxy/utils/Initializable.sol";
import {IERC20Upgradeable} from "@openzeppelin/upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/upgradeable/contracts/access/OwnableUpgradeable.sol";

import {Concero} from "./Concero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {Storage} from "./Libraries/Storage.sol";

///////////////////////////////
/////////////ERROR/////////////
///////////////////////////////
error Orchestrator_UnableToCompleteDelegateCall(bytes delegateError);
error Orchestrator_FoTNotAllowedYet();

contract Orchestrator is Initializable, UUPSUpgradeable, OwnableUpgradeable, Storage {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  
  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
  address internal s_dexSwap;
  address internal s_concero;
  
  ////////////////
  ///INITIALIZE///
  ////////////////
  function Initializable(address _dexSwap, address _concero) public payable initializer onlyOwner {
    s_dexSwap = _dexSwap;
    s_concero = _concero;
  }

  ///////////////////
  ///AUTHORIZATION///
  ///////////////////
  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    
  }

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (LibConcero.isNativeToken(token)) {
      if (msg.value != amount) revert Storage_InvalidAmount();
    } else {
      uint256 balance = LibConcero.getBalance(token, msg.sender);
      if (balance < amount) revert Storage_InvalidAmount();
    }

    _;
  }

  modifier validateBridgeData(BridgeData calldata _bridgeData) {
    if (_bridgeData.amount == 0) {
      revert Storage_InvalidAmount();
    }
    _;
  }

  modifier validateSwapData(IDexSwap.SwapData[] calldata _srcSwapData) {
    if (_srcSwapData.length == 0) {
      revert IDexSwap.InvalidSwapData();
    } 

    if (LibConcero.isNativeToken(_srcSwapData[0].fromToken)) {
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

    (bool bridgeSuccess, bytes memory bridgeError) = s_concero.delegatecall(
        abi.encodeWithSelector(
            Concero.startBridge.selector,
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
    IERC20Upgradeable(fromToken).safeTransferFrom(msg.sender, address(s_concero), bridgeData.amount);    
    
    (bool bridgeSuccess, bytes memory bridgeError) = s_concero.delegatecall(
        abi.encodeWithSelector(
            Concero.startBridge.selector,
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
        (bool swapSuccess, bytes memory swapError) = s_dexSwap.delegatecall(
            abi.encodeWithSelector(
                IDexSwap.conceroEntry.selector,
                _srcSwapData,
                nativeAmount
            )
        );
        if(swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    } else {
        uint256 balanceBefore = IERC20Upgradeable(fromToken).balanceOf(s_dexSwap);
        IERC20Upgradeable(fromToken).safeTransferFrom(msg.sender, s_dexSwap, fromAmount);
        uint256 balanceAfter = IERC20Upgradeable(fromToken).balanceOf(s_dexSwap);

        //TODO: deal with FoT tokens.
        amountReceived = balanceAfter - balanceBefore;

        if(amountReceived != fromAmount) revert Orchestrator_FoTNotAllowedYet();

        (bool swapSuccess, bytes memory swapError) = s_dexSwap.delegatecall(
            abi.encodeWithSelector(
                IDexSwap.conceroEntry.selector,
                _srcSwapData,
                nativeAmount
            )
        );
        if(swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    }
  }
}