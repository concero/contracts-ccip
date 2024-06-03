// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/upgradeable/contracts/proxy/utils/Initializable.sol";
import {IERC20Upgradeable} from "@openzeppelin/upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/upgradeable/contracts/access/OwnableUpgradeable.sol";

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

contract OrchestratorV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable, Storage {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  
  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  event Orchestrator_ContractInitialized();

  constructor() {
  _disableInitializers();
  }

  ////////////////
  ///INITIALIZE///
  ////////////////
  function initialize(address _dexSwap, address _concero) external payable initializer onlyOwner {
    s_dexSwap = _dexSwap;
    s_concero = _concero;
    __Ownable_init();

    emit Orchestrator_ContractInitialized();
  }

  ///////////////////
  ///AUTHORIZATION///
  ///////////////////
  //@audit Should I do anything else here?
  function _authorizeUpgrade(address _newImplementation) internal override onlyOwner {
  }

  ///////////////
  ///MODIFIERS///
  ///////////////
  modifier tokenAmountSufficiency(address token, uint256 amount) {
    if (token == address(0)) {
      if (msg.value != amount) revert Orchestrator_InvalidAmount();
    } else {
      uint256 balance = IERC20Upgradeable(token).balanceOf(msg.sender);
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

    (bool bridgeSuccess, bytes memory bridgeError) = s_concero.delegatecall(
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

    IERC20Upgradeable(fromToken).safeTransferFrom(msg.sender, address(this), bridgeData.amount);    
    
    (bool bridgeSuccess, bytes memory bridgeError) = s_concero.delegatecall(
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
  //@audit USING DEXSwap storage
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
        uint256 balanceBefore = IERC20Upgradeable(fromToken).balanceOf(address(this));
        IERC20Upgradeable(fromToken).safeTransferFrom(msg.sender, address(this), fromAmount);
        uint256 balanceAfter = IERC20Upgradeable(fromToken).balanceOf(address(this));

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