// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {ConceroAutomation} from "./ConceroAutomation.sol";
import {LPToken} from "./LPToken.sol";

import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {IStorage} from "./Interfaces/IStorage.sol";

import {ParentStorage} from "contracts/Libraries/ParentStorage.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the balance is not sufficient
error ParentPool_InsufficientBalance();
///@notice error emitted when the receiver is the address(0)
error ParentPool_InvalidAddress();
///@notice error emitted when the CCIP message sender is not allowed.
error ParentPool_SenderNotAllowed(address _sender);
///@notice error emitted when an attempt to create a new request is made while other is still active.
error ParentPool_ActiveRequestNotFulfilledYet();
///@notice error emitted when an attempt to send value to a not allowed receiver is made
error ParentPool_DestinationNotAllowed();  //@audit not being used
///@notice error emitted when the contract doesn't have enough link balance
error ParentPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when a LP try to deposit liquidity on the contract without pools
error ParentPool_ThereIsNoPoolToDistribute();
///@notice emitted in depositLiquidity when the input amount is not enough
error ParentPool_AmountBelowMinimum(uint256 minAmount);
///@notice emitted in withdrawLiquidity when the amount to withdraws is bigger than the balance
error ParentPool_AmountNotAvailableYet(uint256 received);
///@notice emitted in depositLiquidity when the input token is not allowed
error ParentPool_TokenNotAllowed(address token);  //@audit not being used
///@notice error emitted when the caller is not the messenger
error ParentPool_NotMessenger(address caller);
///@notice error emitted when the chain selector input is invalid
error ParentPool_ChainNotAllowed(uint64 chainSelector);
///@notice error emitted when the caller is not the Orchestrator
error ParentPool_ItsNotOrchestrator(address caller);
///@notice error emitted when the max amount accepted by the pool is reached
error ParentPool_MaxCapReached(uint256 maxCap);
///@notice error emitted when it's not the proxy calling the function
error ParentPool_CallerIsNotTheProxy(address caller);

contract ParentPool is CCIPReceiver, ParentStorage, FunctionsClient {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  using FunctionsRequest for FunctionsRequest.Request;
  using SafeERC20 for IERC20;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice ParentPool proxy address
  address private immutable i_parentProxy;
  ///@notice Orchestrator Proxy immutable address
  address private immutable i_infraProxy;
  ///@notice Chainlink Link Token interface
  LinkTokenInterface private immutable i_linkToken;
  ///@notice immutable variable to store the USDC address.
  IERC20 immutable i_USDC;
  ///@notice Pool liquidity token
  LPToken public immutable i_lp;
  ///@notice Concero Automation contract
  ConceroAutomation private immutable i_automation;
  ///@notice Chainlink Function Don ID
  bytes32 private immutable i_donId;
  ///@notice Chainlink Functions Protocol Subscription ID
  uint64 private immutable i_subscriptionId;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Magic Number Removal
  uint256 private constant ALLOWED = 1;
  uint256 private constant USDC_DECIMALS = 10 ** 6;
  uint256 private constant LP_TOKEN_DECIMALS = 10 ** 18;
  uint256 private constant MIN_DEPOSIT = 100 * 10 ** 6;
  uint256 private constant PRECISION_HANDLER = 10 ** 10;

  ///@notice Chainlink Functions Gas Limit
  uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  ///@notice Chainlink Function Gas Overhead
  uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000; //Do we need this?
  ///@notice JS Code for Chainlink Functions
  string internal constant JS_CODE = "";

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a new withdraw request is made
  event ParentPool_WithdrawRequest(address caller, IERC20 token, uint256 deadline);
  ///@notice event emitted when a value is withdraw from the contract
  event ParentPool_Withdrawn(address indexed to, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain tx is received.
  event ParentPool_CCIPReceived(bytes32 indexed ccipMessageId, uint64 srcChainSelector, address sender, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain message is sent.
  event ParentPool_MessageSent(bytes32 messageId, uint64 destinationChainSelector, address receiver, address linkToken, uint256 fees);
  ///@notice event emitted in depositLiquidity when a deposit is successful executed
  event ParentPool_SuccessfulDeposited(address indexed liquidityProvider, uint256 _amount, IERC20 _token);
  ///@notice event emitted when a request is updated with the total USDC to withdraw
  event ParentPool_RequestUpdated(address liquidityProvider);
  ///@notice event emitted when the Functions request return error
  event FunctionsRequestError(bytes32 requestId, IParentPool.RequestType requestType);

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice CCIP Modifier to check Chains And senders
   * @param _chainSelector Id of the source chain of the message
   * @param _sender address of the sender contract
   */
  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (s_contractsToReceiveFrom[_chainSelector][_sender] != ALLOWED) revert ParentPool_SenderNotAllowed(_sender);
    _;
  }

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (isMessenger(msg.sender) == false) revert ParentPool_NotMessenger(msg.sender);
    _;
  }

  /**
   * @notice CCIP Modifier to check receivers for a specific chain
   * @param _chainSelector Id of the destination chain
   */
  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_poolToSendTo[_chainSelector] == address(0)) revert ParentPool_ChainNotAllowed(_chainSelector);
    _;
  }

  /**
   * @notice modifier to ensure if the function is being executed in the proxy context.
   */
  modifier isProxy() {
    if (address(this) != i_parentProxy) revert ParentPool_CallerIsNotTheProxy(address(this));
    _;
  }

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  receive() external payable {}

  constructor(
    address _parentProxy,
    address _link,
    bytes32 _donId,
    uint64 _subscriptionId,
    address _functionsRouter,
    address _ccipRouter,
    address _usdc,
    address _lpToken,
    address _automation,
    address _orchestrator,
    address _owner
  ) ParentStorage(_owner) CCIPReceiver(_ccipRouter) FunctionsClient(_functionsRouter) {
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    i_parentProxy = _parentProxy;
    i_linkToken = LinkTokenInterface(_link);
    i_USDC = IERC20(_usdc);
    i_lp = LPToken(_lpToken);
    i_automation = ConceroAutomation(_automation);
    i_infraProxy = _orchestrator;
  }

  ////////////////////////
  ///EXTERNAL FUNCTIONS///
  ////////////////////////
  /**
   * @notice function to the Concero Orchestrator contract take loans
   * @param _token address of the token being loaned
   * @param _amount being loaned
   * @param _receiver address of the user that will receive the amount
   * @dev only the Orchestrator contract should be able to call this function
   * @dev for ether transfer, the _receiver need to be known and trusted
   */
  function orchestratorLoan(address _token, uint256 _amount, address _receiver) external payable isProxy {
    if (msg.sender != i_infraProxy) revert ParentPool_ItsNotOrchestrator(msg.sender);
    if (_receiver == address(0)) revert ParentPool_InvalidAddress();
    if (_amount > (IERC20(_token).balanceOf(address(this)) - s_withdrawRequests)) revert ParentPool_InsufficientBalance();

    s_loansInUse = s_loansInUse + _amount;

    IERC20(_token).safeTransfer(_receiver, _amount);
  }

  /**
   * @notice Function for user to deposit liquidity of allowed tokens
   * @param _usdcAmount the amount to be deposited
   */
  function depositLiquidity(uint256 _usdcAmount) external isProxy {
    if (_usdcAmount < MIN_DEPOSIT) revert ParentPool_AmountBelowMinimum(MIN_DEPOSIT);
    if (s_maxDeposit != 0 && s_maxDeposit < _usdcAmount + i_USDC.balanceOf(address(this)) + s_loansInUse) revert ParentPool_MaxCapReached(s_maxDeposit);

    uint256 numberOfPools = poolsToDistribute.length;

    if (numberOfPools < 1) revert ParentPool_ThereIsNoPoolToDistribute();

    uint256 amountToDistribute = ((_usdcAmount * PRECISION_HANDLER) / (numberOfPools + 1)) / PRECISION_HANDLER;

    bytes[] memory args = new bytes[](2);
    args[0] = abi.encodePacked(s_hashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);

    //Commented so tests don't fail.
    bytes32 requestId /* = _sendRequest(args, JS_CODE)*/; // No JS code yet.

    s_requests[requestId] = IParentPool.CLARequest({
      requestType: IParentPool.RequestType.GetTotalUSDC,
      liquidityProvider: msg.sender,
      usdcBeforeRequest: i_USDC.balanceOf(address(this)) + s_loansInUse,
      lpSupplyBeforeRequest: i_lp.totalSupply(),
      amount: _usdcAmount //Here it's the usdc amount
    });

    emit ParentPool_SuccessfulDeposited(msg.sender, _usdcAmount, i_USDC);

    i_USDC.safeTransferFrom(msg.sender, address(this), _usdcAmount);

    _ccipSend(numberOfPools, amountToDistribute);
  }

  /**
   * @notice Function to allow Liquidity Providers to start the Withdraw of their USDC deposited
   * @param _lpAmount the amount of lp token the user wants to burn to get USDC back.
   */
  function startWithdrawal(uint256 _lpAmount) external isProxy{
    if (i_lp.balanceOf(msg.sender) < _lpAmount) revert ParentPool_InsufficientBalance();
    if (s_pendingWithdrawRequests[msg.sender].amountToBurn > 0) revert ParentPool_ActiveRequestNotFulfilledYet();

    uint256 numberOfPools = poolsToDistribute.length;

    bytes[] memory args = new bytes[](15);
    for(uint i; i < numberOfPools; i++){
      args[i] = abi.encodePacked(poolsToDistribute[i].chainSelector);
    }

    //Commented so tests don't fail.
    bytes32 requestId /*= _sendRequest(args, JS_CODE)*/; // No JS code yet.

    s_requests[requestId] = IParentPool.CLARequest({
      requestType: IParentPool.RequestType.PerformWithdrawal,
      liquidityProvider: msg.sender,
      usdcBeforeRequest: 0,
      lpSupplyBeforeRequest: i_lp.totalSupply(),
      amount: _lpAmount //Here it's the lp amount
    });

    emit ParentPool_WithdrawRequest(msg.sender, i_USDC, block.timestamp + 597_600);
  }

  /**
   * @notice Function called to finalize the withdraw process.
   * @dev The msg.sender will be used to load the withdraw request data
   * if the request received the total amount requested from other pools,
   * the withdraw will be finalize. If not, it must revert
   */
  function completeWithdrawal() external isProxy {
    IParentPool.WithdrawRequests memory withdraw = s_pendingWithdrawRequests[msg.sender];

    if (withdraw.amountToReceive > 0) revert ParentPool_AmountNotAvailableYet(withdraw.amountToReceive);

    if (withdraw.amountEarned > i_USDC.balanceOf(address(this))) revert ParentPool_InsufficientBalance();

    emit ParentPool_Withdrawn(msg.sender, address(i_USDC), withdraw.amountEarned);

    s_withdrawRequests = s_withdrawRequests > withdraw.amountEarned
    ? s_withdrawRequests - withdraw.amountEarned
    : 0;

    delete s_pendingWithdrawRequests[msg.sender];

    IERC20(i_lp).safeTransferFrom(msg.sender, address(this), withdraw.amountToBurn);

    i_lp.burn(withdraw.amountToBurn);

    i_USDC.safeTransfer(msg.sender, withdraw.amountEarned);
  }

  ////////////////
  /// INTERNAL ///
  ////////////////
  /**
   * @notice CCIP function to receive bridged values
   * @param any2EvmMessage the CCIP message
   * @dev only allowed chains and sender must be able to deliver a message in this function.
   */
  function _ccipReceive(
    Client.Any2EVMMessage memory any2EvmMessage
  ) internal override onlyAllowlistedSenderAndChainSelector(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) {
    //2 scenarios in which we will receive data
    //1. Fee of cross-chains transactions
    //2. Transfers of amounts to be withdraw
    (address _liquidityProvider, address _user, uint256 receivedFee) = abi.decode(any2EvmMessage.data, (address, address, uint256));

    uint256 amountMinusFees = (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);

    if (receivedFee > 0) {
      IStorage.Transaction memory transaction = IStorage(i_infraProxy).getTransactionsInfo(any2EvmMessage.messageId);

      if(transaction.ccipMessageId == any2EvmMessage.messageId && transaction.isConfirmed == false || transaction.ccipMessageId == 0){
        i_USDC.safeTransfer(_user, amountMinusFees);
        //We don't subtract it here because the loan was not performed. And the value is not summed into the `s_loanInUse` variable.
      } else  {
        //subtract the amount from the committed total amount
        s_loansInUse = s_loansInUse - amountMinusFees;
      }
    } else if (_liquidityProvider != address(0)) {
      IParentPool.WithdrawRequests storage request = s_pendingWithdrawRequests[_liquidityProvider];

      //update the corresponding withdraw request
      request.amountToReceive = request.amountToReceive >= any2EvmMessage.destTokenAmounts[0].amount
        ? request.amountToReceive - any2EvmMessage.destTokenAmounts[0].amount
        : 0;
        
      s_withdrawRequests = s_withdrawRequests + any2EvmMessage.destTokenAmounts[0].amount;
    }

    emit ParentPool_CCIPReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector,
      abi.decode(any2EvmMessage.sender, (address)),
      any2EvmMessage.destTokenAmounts[0].token,
      any2EvmMessage.destTokenAmounts[0].amount
    );
  }

  /**
   * @notice Function to distribute funds automatically right after LP deposits into the pool
   * @dev this function will only be called internally.
   */
  function _ccipSend(uint256 _numberOfPools, uint256 _amountToDistribute) internal returns (bytes32 messageId) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: address(i_USDC), amount: _amountToDistribute});

    tokenAmounts[0] = tokenAmount;

    for (uint256 i; i < _numberOfPools; ) {
      IParentPool.Pools memory pool = poolsToDistribute[i];

      Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
        receiver: abi.encode(pool.poolAddress),
        data: abi.encode(address(0), address(0), 0), //Here the 1° address is (0) because this is the Parent Pool and we never send to withdraw in another place.
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 350_000})),
        feeToken: address(i_linkToken)
      });

      uint256 fees = IRouterClient(i_ccipRouter).getFee(pool.chainSelector, evm2AnyMessage);

      if (fees > i_linkToken.balanceOf(address(this))) revert ParentPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

      i_USDC.approve(i_ccipRouter, _amountToDistribute);
      i_linkToken.approve(i_ccipRouter, fees);

      messageId = IRouterClient(i_ccipRouter).ccipSend(pool.chainSelector, evm2AnyMessage);

      emit ParentPool_MessageSent(messageId, pool.chainSelector, pool.poolAddress, address(i_linkToken), fees);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Function to send a Request to Chainlink Functions
   * @param _args the arguments for the request as bytes array
   * @param _jsCode the JScode that will be executed.
   */
  function _sendRequest(bytes[] memory _args, string memory _jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(_jsCode);
    req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
    req.setBytesArgs(_args);

    return _sendRequest(req.encodeCBOR(), i_subscriptionId, CL_FUNCTIONS_CALLBACK_GAS_LIMIT, i_donId);
  }

  /**
   * @notice Chainlink Functions fallback function
   * @param requestId the ID of the request sent
   * @param response the response of the request sent
   * @param err the error of the request sent
   * @dev response & err will never be empty or populated at same time.
   */
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    IParentPool.CLARequest storage request = s_requests[requestId];

    if (err.length > 0) {
      emit FunctionsRequestError(requestId, request.requestType);
      return;
    }

    uint256 crossChainBalance = abi.decode(response, (uint256));
    uint256 usdcReserve = request.usdcBeforeRequest + crossChainBalance;

    if (request.requestType == IParentPool.RequestType.GetTotalUSDC) {
      _updateDepositInfoAndMintLPTokens(request.liquidityProvider, request.lpSupplyBeforeRequest, request.amount, usdcReserve);
    } else if (request.requestType == IParentPool.RequestType.PerformWithdrawal) {
      _updateUsdcAmountEarned(request.liquidityProvider, request.lpSupplyBeforeRequest, request.amount, usdcReserve);
    }
  }

  ///////////////
  /// PRIVATE ///
  ///////////////
  /**
   * @notice Function called by Chainlink Functions fulfillRequest to update deposit information
   * @param _liquidityProvider The Address of the user that initiate the withdraw process
   * @param _lpSupplyBeforeRequest the LP totalSupply() before request
   * @param _usdcDeposited the amount of USDC deposited
   * @param _totalUSDCCrossChain The total cross chain balance
   * @dev This function must be called only by an allowed Messenger & must not revert
   * @dev _totalUSDCCrossChain MUST have 10**6 decimals.
   */
  function _updateDepositInfoAndMintLPTokens(address _liquidityProvider, uint256 _lpSupplyBeforeRequest, uint256 _usdcDeposited, uint256 _totalUSDCCrossChain) private {
    //_totalUSDCCrossChain == the sum of all chains balance + commits

    uint256 crossChainBalanceConverted = _convertToLPTokenDecimals(_totalUSDCCrossChain);
    uint256 amountDepositedConverted = _convertToLPTokenDecimals(_usdcDeposited);

    //N° lpTokens = (((Total USDC Liq + user deposit) * Total sToken) / Total USDC Liq) - Total sToken
    //If less than ALLOWED, means it's zero.
    uint256 lpTokensToMint = _lpSupplyBeforeRequest > ALLOWED
      ? (((crossChainBalanceConverted + amountDepositedConverted) * _lpSupplyBeforeRequest) / crossChainBalanceConverted) - _lpSupplyBeforeRequest //@audit Need to optimize it
      : amountDepositedConverted;

    i_lp.mint(_liquidityProvider, lpTokensToMint);
  }

  /**
   * @notice Function to updated cross-chain rewards will be paid to liquidity providers in the end of
   * withdraw period.
   * @param _liquidityProvider Liquidity Provider address to update info.
   * @param _lpSupplyBeforeRequest the LP totalSupply() before request
   * @param _lpToBurn the LP Amount a Liquidity Provider wants to burn
   * @param _totalUSDCCrossChain The total cross chain balance
   * @dev This function must be called only by an allowed Messenger & must not revert
   * @dev _totalUSDCCrossChain MUST have 10**6 decimals.
   */
  function _updateUsdcAmountEarned(address _liquidityProvider, uint256 _lpSupplyBeforeRequest, uint256 _lpToBurn, uint256 _totalUSDCCrossChain) private {
    uint256 numberOfPools = poolsToDistribute.length;
    uint256 totalCrossChainBalance = _totalUSDCCrossChain + i_USDC.balanceOf(address(this)) + s_loansInUse;

    //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
    uint256 amountToWithdraw = (((_convertToLPTokenDecimals(totalCrossChainBalance) * _lpToBurn) * PRECISION_HANDLER) / _lpSupplyBeforeRequest) /
      PRECISION_HANDLER;

    IParentPool.WithdrawRequests memory request = IParentPool.WithdrawRequests({
      amountEarned: _convertToUSDCTokenDecimals(amountToWithdraw),
      amountToBurn: _lpToBurn,
      amountToRequest: _convertToUSDCTokenDecimals(amountToWithdraw) / (numberOfPools + 1), //Cross-chain Pools + MasterPool
      amountToReceive: (_convertToUSDCTokenDecimals(amountToWithdraw) * numberOfPools) / (numberOfPools + 1), //The portion of the money that is not on MasterPool
      token: address(i_USDC),
      liquidityProvider: _liquidityProvider,
      deadline: block.timestamp + 597_600 //6days & 22h
    });

    s_withdrawRequests = s_withdrawRequests + _convertToUSDCTokenDecimals(amountToWithdraw) / (numberOfPools + 1);
    
    s_pendingWithdrawRequests[_liquidityProvider] = request;
    i_automation.addPendingWithdrawal(request);

    emit ParentPool_RequestUpdated(_liquidityProvider);
  }

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  /**
   * @notice Internal function to convert USDC Decimals to LP Decimals
   * @param _usdcAmount the amount of USDC
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToLPTokenDecimals(uint256 _usdcAmount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_usdcAmount * LP_TOKEN_DECIMALS) / USDC_DECIMALS;
  }

  /**
   * @notice Internal function to convert LP Decimals to USDC Decimals
   * @param _lpAmount the amount of LP
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToUSDCTokenDecimals(uint256 _lpAmount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_lpAmount * USDC_DECIMALS) / LP_TOKEN_DECIMALS;
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

  //////////////////////////////
  /// HELPER TO REMOVE LATER ///
  //////////////////////////////
  //Only used to test locally and mock functions operations.
  function updateUSDCAmountManually(address _liquidityProvider, uint256 _lpSupplyBeforeRequest, uint256 _depositedAmount, uint256 _crossChainBalance) external {
    _updateDepositInfoAndMintLPTokens(_liquidityProvider, _lpSupplyBeforeRequest, _depositedAmount, _crossChainBalance);
  }

  function updateUSDCAmountEarned(address _liquidityProvider,uint256 _lpSupplyBeforeRequest, uint256 _lpToBurn,  uint256 _totalUSDC) external {
    _updateUsdcAmountEarned(_liquidityProvider, _lpSupplyBeforeRequest, _lpToBurn, _totalUSDC);
  }
}
