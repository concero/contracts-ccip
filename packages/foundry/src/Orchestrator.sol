// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/upgradeable/contracts/proxy/utils/Initializable.sol";
import {IERC20Upgradeable} from "@openzeppelin/upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {Concero} from "./Concero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {Storage} from "./Libraries/Storage.sol";

///////////////////////////////
/////////////ERROR/////////////
///////////////////////////////
error Orchestrator_UnableToCompleteDelegateCall(bytes delegateError);

contract Orchestrator is Storage, Initializable, UUPSUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  ///////////////
  ///VARIABLES///
  ///////////////
  address private s_dexSwap;
  address private s_pool;
  address private s_concero;
  
  ////////////////
  ///INITIALIZE///
  ////////////////
  function Initializable() public payable initializer {

  }

  ////////////////////
  ///DELEGATE CALLS///
  ////////////////////

  //Expected Params
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
  ) external tokenAmountSufficiency(getToken(bridgeData.tokenType), bridgeData.amount) validateBridgeData(bridgeData) {

    address fromToken = getToken(bridgeData.tokenType);
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
    address fromToken = swapData[0].fromToken;
    uint256 fromAmount = swapData[0].fromAmount;

    if(fromToken == address(0)){
        (bool swapSuccess, bytes memory swapError) = dexSwap.delegatecall{value: msg.value}(
            abi.encodeWithSelector(
                IDexSwap.conceroEntry.selector,
                _srcSwapData,
                nativeAmount
            )
        );
        if(swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);
    } else {
        uint256 balanceBefore = IERC20Upgradeable(fromToken).balanceOf(fromToken, address(dexSwap));
        IERC20Upgradeable(fromToken).safeTransferFrom(msg.sender, address(dexSwap), fromAmount);
        uint256 balanceAfter = IERC20Upgradeable(fromToken).balanceOf(fromToken, address(dexSwap));

        //TODO: deal with FoT tokens.
        amountReceived = balanceAfter - balanceBefore;

        if(amountReceived != fromAmount) revert Orchestrator_FoTNotAllowedYet();

        (bool swapSuccess, bytes memory swapError) = dexSwap.delegatecall(
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