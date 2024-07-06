// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsClient.sol";
import {IConcero} from "./Interfaces/IConcero.sol";
import {IDexSwap} from "./Interfaces/IDexSwap.sol";
import {StorageSetters} from "./Libraries/StorageSetters.sol";
import {LibConcero} from "./Libraries/LibConcero.sol";
import {IOrchestrator} from "./Interfaces/IOrchestrator.sol";
import {USDC_ARBITRUM, USDC_BASE, USDC_OPTIMISM, USDC_POLYGON, USDC_POLYGON_AMOY, USDC_ARBITRUM_SEPOLIA, USDC_BASE_SEPOLIA, USDC_OPTIMISM_SEPOLIA} from "./Constants.sol";

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
///@notice error emitted when a non-messenger address calls
error Orchestrator_NotMessenger(address);
///@notice error emitted when the chosen token is not allowed
error Orchestrator_TokenTypeOutOfBounds();
///@notice error emitted when the chain index is incorrect
error Orchestrator_ChainIndexOutOfBounds();
///@notice error emitted when the token to bridge is not USDC
error Orchestrator_InvalidBridgeToken();

contract Orchestrator is IFunctionsClient, IOrchestrator, StorageSetters {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
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

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (isMessenger(msg.sender) == false) revert Orchestrator_NotMessenger(msg.sender);
    _;
  }
  
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
  ) external validateSwapData(srcSwapData) validateBridgeData(bridgeData) validateSwapData(dstSwapData){
    if(srcSwapData[srcSwapData.length - 1].toToken != getToken(bridgeData.tokenType, i_chainIndex)) revert Orchestrator_InvalidSwapData();
    // if(dstSwapData[0].toToken != getToken(bridgeData.tokenType, bridgeData.dstChainSelector)) revert Orchestrator_InvalidSwapData();

    //Swap -> money come back to this contract       
    bridgeData.amount = _swap(srcSwapData, 0, false, address(this));

    (bool bridgeSuccess, bytes memory bridgeError) = i_concero.delegatecall(abi.encodeWithSelector(IConcero.startBridge.selector, bridgeData, dstSwapData));
    if (bridgeSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(bridgeError);
  }

  function swap(
    IDexSwap.SwapData[] calldata _swapData,
    address _receiver
  ) external payable validateSwapData(_swapData) tokenAmountSufficiency(_swapData[0].fromToken, _swapData[0].fromAmount) {
    _swap(_swapData, msg.value, true, _receiver);
  }

  function bridge(
    BridgeData memory bridgeData,
    IDexSwap.SwapData[] calldata dstSwapData
  ) external validateBridgeData(bridgeData) validateSwapData(dstSwapData){
    {
    uint256 userBalance = IERC20(getToken(bridgeData.tokenType, i_chainIndex)).balanceOf(msg.sender);
    if (userBalance < bridgeData.amount) revert Orchestrator_InvalidAmount();
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

    uint256 toTokenBalanceBefore = IERC20(toToken).balanceOf(address(this));

    if (fromToken != address(0)) {
      LibConcero.transferFromERC20(fromToken, msg.sender, address(this), fromAmount);
      if (isFeesNeeded) swapData[0].fromAmount -= (fromAmount / CONCERO_FEE_FACTOR);
    } else {
      if (isFeesNeeded) _nativeAmount -= (_nativeAmount / CONCERO_FEE_FACTOR);
    }

    (bool swapSuccess, bytes memory swapError) = i_dexSwap.delegatecall(abi.encodeWithSelector(IDexSwap.conceroEntry.selector, swapData, _nativeAmount, _receiver));
    if (swapSuccess == false) revert Orchestrator_UnableToCompleteDelegateCall(swapError);

    emit Orchestrator_SwapSuccess();

    uint256 toTokenBalanceAfter = IERC20(toToken).balanceOf(address(this));
    return toTokenBalanceAfter - toTokenBalanceBefore;
  }

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  function getTransactionsInfo(bytes32 _ccipMessageId) external view returns (Transaction memory transaction) {
    transaction = s_transactions[_ccipMessageId];
  }

  /**
   * @notice Function to check for allowed tokens on specific networks
   * @param token The enum flag of the token
   * @param _chainIndex the index of the chain
   */
  function getToken(CCIPToken token, Chain _chainIndex) internal view returns (address) {
    address[4][2] memory tokens;

    // Initialize BNM addresses
    tokens[uint(CCIPToken.bnm)][uint(Chain.arb)] = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D; // arb
    tokens[uint(CCIPToken.bnm)][uint(Chain.base)] = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e; // base
    tokens[uint(CCIPToken.bnm)][uint(Chain.opt)] = 0x8aF4204e30565DF93352fE8E1De78925F6664dA7; // opt
    tokens[uint(CCIPToken.bnm)][uint(Chain.pol)] = 0xcab0EF91Bee323d1A617c0a027eE753aFd6997E4; // pol

    // Initialize USDC addresses
    tokens[uint(CCIPToken.usdc)][uint(Chain.arb)] = block.chainid == 42161 ? USDC_ARBITRUM : 	USDC_ARBITRUM_SEPOLIA;
    tokens[uint(CCIPToken.usdc)][uint(Chain.base)] = block.chainid == 8453 ? USDC_BASE : USDC_BASE_SEPOLIA;
    tokens[uint(CCIPToken.usdc)][uint(Chain.opt)] = block.chainid == 10 ? USDC_OPTIMISM : USDC_OPTIMISM_SEPOLIA;
    tokens[uint(CCIPToken.usdc)][uint(Chain.pol)] = block.chainid == 137 ? USDC_POLYGON : USDC_POLYGON_AMOY;

    if (uint256(token) >= tokens.length) revert Orchestrator_TokenTypeOutOfBounds();
    if (uint256(_chainIndex) >= tokens[uint256(token)].length) revert Orchestrator_ChainIndexOutOfBounds();

    return tokens[uint256(token)][uint256(_chainIndex)];
  }

  /**
   * @notice Internal function to convert USDC Decimals to LP Decimals
   * @param _amount the amount of USDC
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToUSDCDecimals(uint256 _amount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_amount * USDC_DECIMALS) / STANDARD_TOKEN_DECIMALS;
  }

  /**
   * @notice Function to check if a caller address is an allowed messenger
   * @param _messenger the address of the caller
   */
  function isMessenger(address _messenger) internal pure returns (bool _isMessenger) {
    address[] memory messengers = new address[](4); //Number of messengers. To define.
    messengers[0] = 0x05CF0be5cAE993b4d7B70D691e063f1E0abeD267; //fake messenger from foundry environment
    messengers[1] = address(0);
    messengers[2] = address(0);
    messengers[3] = address(0);

    for (uint256 i; i < messengers.length; ) {
      if (_messenger == messengers[i]) {
        return true;
      }
      unchecked {
        ++i;
      }
    }
    return false;
  }
}
