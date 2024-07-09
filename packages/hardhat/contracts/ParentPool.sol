// SPDX-License-Identifier: MIT
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
import {IOrchestrator} from "./Interfaces/IOrchestrator.sol";
import {Orchestrator} from "./Orchestrator.sol";

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
///@notice error emitted when the contract doesn't have enough link balance
error ParentPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when a LP try to deposit liquidity on the contract without pools
error ParentPool_ThereIsNoPoolToDistribute();
///@notice emitted in depositLiquidity when the input amount is not enough
error ParentPool_AmountBelowMinimum(uint256 minAmount);
///@notice emitted in withdrawLiquidity when the amount to withdraws is bigger than the balance
error ParentPool_AmountNotAvailableYet(uint256 received);
///@notice error emitted when the caller is not the Orchestrator
error ParentPool_ItsNotOrchestrator(address caller);
///@notice error emitted when the max amount accepted by the pool is reached
error ParentPool_MaxCapReached(uint256 maxCap);
///@notice error emitted when it's not the proxy calling the function
error ParentPool_CallerIsNotTheProxy(address caller);
///@notice error emitted when the caller is not the owner
error ParentPool_NotContractOwner();

contract ParentPool is CCIPReceiver, FunctionsClient, ParentStorage {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  using FunctionsRequest for FunctionsRequest.Request;
  using SafeERC20 for IERC20;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Magic Number Removal
  uint256 private constant ALLOWED = 1;
  uint256 private constant USDC_DECIMALS = 10 ** 6;
  uint256 private constant LP_TOKEN_DECIMALS = 10 ** 18;
  uint256 private constant MIN_DEPOSIT = 100 * 10 ** 6;
  uint256 private constant PRECISION_HANDLER = 10 ** 10;
  uint256 private constant WITHDRAW_DEADLINE = 597_600;
  uint256 private constant ITERATION_COSTS = 808;
  uint256 private constant ARRAY_MANIPULATION = 10_000;
  uint256 private constant AUTOMATION_OVERHEARD = 80_000;
  uint256 private constant NODE_PREMIUM = 150;
  ///@notice variable to access parent pool costs
  uint64 private constant BASE_CHAIN_SELECTOR = 15971525489660198786;
  ///@notice variable to store the costs of updating store on CLF callback
  uint256 private constant WRITE_FUNCTIONS_COST = 600_000;
  ///@notice Chainlink Functions Gas Limit
  uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  ///@notice JS Code for Chainlink Functions
  string internal constant JS_CODE =
    "try { const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js'; const q = 'https://raw.githubusercontent.com/concero/contracts-ccip/' + 'master' + '/packages/hardhat/tasks/CLFScripts/dist/pool/getTotalBalance.min.js'; const [t, p] = await Promise.all([fetch(u), fetch(q)]); const [e, c] = await Promise.all([t.text(), p.text()]); const g = async s => { return ( '0x' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))) .map(v => ('0' + v.toString(16)).slice(-2).toLowerCase()) .join('') ); }; const r = await g(c); const x = await g(e); const b = bytesArgs[0].toLowerCase(); const o = bytesArgs[1].toLowerCase(); if (r === b && x === o) { const ethers = new Function(e + '; return ethers;')(); return await eval(c); } throw new Error(`${r}!=${b}||${x}!=${o}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";

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
  ///@notice Contract Owner
  address immutable i_owner;

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
  ///@notice event emitted when a Concero pool is added
  event ParentPool_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a allowed Cross-chain contract is updated
  event ParentPool_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256 isAllowed);
  ///@notice event emitted in setConceroContract when the address is emitted
  event ParentPool_ConceroContractUpdated(address concero);
  ///@notice event emitted when a contract is removed from the distribution array
  event ParentPool_ChainAndAddressRemoved(uint64 _chainSelector);
  ///@notice event emitted when the MasterPool Cap is increased
  event ParentPool_MasterPoolCapUpdated(uint256 _newCap);

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
   * @notice modifier to ensure if the function is being executed in the proxy context.
   */
  modifier isProxy() {
    if (address(this) != i_parentProxy) revert ParentPool_CallerIsNotTheProxy(address(this));
    _;
  }

  modifier onlyOwner() {
    if (msg.sender != i_owner) revert ParentPool_NotContractOwner();
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
  ) CCIPReceiver(_ccipRouter) FunctionsClient(_functionsRouter) {
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    i_parentProxy = _parentProxy;
    i_linkToken = LinkTokenInterface(_link);
    i_USDC = IERC20(_usdc);
    i_lp = LPToken(_lpToken);
    i_automation = ConceroAutomation(_automation);
    i_infraProxy = _orchestrator;
    i_owner = _owner;
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

    uint256 numberOfPools = s_poolsToDistribute.length;

    if (numberOfPools < 1) revert ParentPool_ThereIsNoPoolToDistribute();

    uint256 depositFee = _calculateDepositTransactionFee(_usdcAmount);
    uint256 depositMinusFee = _usdcAmount - _convertToUSDCTokenDecimals(depositFee);

    uint256 amountToDistribute = ((depositMinusFee * PRECISION_HANDLER) / (numberOfPools + 1)) / PRECISION_HANDLER;

    bytes[] memory args = new bytes[](2);
    args[0] = abi.encodePacked(s_hashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);

    bytes32 requestId = _sendRequest(args, JS_CODE);
    s_requests[requestId] = IParentPool.CLFRequest({
      requestType: IParentPool.RequestType.GetTotalUSDC,
      liquidityProvider: msg.sender,
      usdcBeforeRequest: i_USDC.balanceOf(address(this)) + s_loansInUse,
      lpSupplyBeforeRequest: i_lp.totalSupply(),
      amount: depositMinusFee
    });

    emit ParentPool_SuccessfulDeposited(msg.sender, _usdcAmount, i_USDC);

    i_USDC.safeTransferFrom(msg.sender, address(this), _usdcAmount);
    i_USDC.safeTransfer(i_infraProxy, _convertToUSDCTokenDecimals(depositFee));

    _ccipSend(numberOfPools, amountToDistribute);
  }

  /**
   * @notice Function to allow Liquidity Providers to start the Withdraw of their USDC deposited
   * @param _lpAmount the amount of lp token the user wants to burn to get USDC back.
   */
  function startWithdrawal(uint256 _lpAmount) external isProxy {
    if (i_lp.balanceOf(msg.sender) < _lpAmount) revert ParentPool_InsufficientBalance();
    if (s_pendingWithdrawRequests[msg.sender].amountToBurn > 0) revert ParentPool_ActiveRequestNotFulfilledYet();

    bytes[] memory args = new bytes[](2);
    args[0] = abi.encodePacked(s_hashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);

    bytes32 requestId = _sendRequest(args, JS_CODE);

    s_requests[requestId] = IParentPool.CLFRequest({
      requestType: IParentPool.RequestType.PerformWithdrawal,
      liquidityProvider: msg.sender,
      usdcBeforeRequest: 0,
      lpSupplyBeforeRequest: i_lp.totalSupply(),
      amount: _lpAmount
    });

    emit ParentPool_WithdrawRequest(msg.sender, i_USDC, block.timestamp + WITHDRAW_DEADLINE);
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

    s_withdrawRequests = s_withdrawRequests > withdraw.amountEarned ? s_withdrawRequests - withdraw.amountEarned : 0;

    delete s_pendingWithdrawRequests[msg.sender];

    uint256 withdrawFees = _calculateWithdrawTransactionsFee(withdraw.amountEarned);
    uint256 withdrawAmountMinusFees = withdraw.amountEarned - _convertToUSDCTokenDecimals(withdrawFees);

    emit ParentPool_Withdrawn(msg.sender, address(i_USDC), withdrawAmountMinusFees);

    IERC20(i_lp).safeTransferFrom(msg.sender, address(this), withdraw.amountToBurn);
    i_lp.burn(withdraw.amountToBurn);

    i_USDC.safeTransfer(i_infraProxy, _convertToUSDCTokenDecimals(withdrawFees));
    i_USDC.safeTransfer(msg.sender, withdrawAmountMinusFees);
  }

  ///////////////////////
  ///SETTERS FUNCTIONS///
  ///////////////////////
  /**
   * @notice function to manage the Cross-chains Concero contracts
   * @param _chainSelector chain identifications
   * @param _contractAddress address of the Cross-chains Concero contracts
   * @param _isAllowed 1 == allowed | Any other value == not allowed
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   * @dev this functions is used on ConceroPool.sol
   */
  function setConceroContractSender(uint64 _chainSelector, address _contractAddress, uint256 _isAllowed) external payable onlyOwner {
    if (_contractAddress == address(0)) revert ParentPool_InvalidAddress();
    s_contractsToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

    emit ParentPool_ConceroSendersUpdated(_chainSelector, _contractAddress, _isAllowed);
  }

  /**
   * @notice function to manage the Cross-chain ConceroPool contracts
   * @param _chainSelector chain identifications
   * @param _pool address of the Cross-chain ConceroPool contract
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   * @dev this functions is used on ConceroPool.sol
   */
  function setPoolsToSend(uint64 _chainSelector, address _pool) external payable onlyOwner {
    if (s_poolToSendTo[_chainSelector] == _pool || _pool == address(0)) revert ParentPool_InvalidAddress();
    s_poolsToDistribute.push(IParentPool.Pools({chainSelector: _chainSelector, poolAddress: _pool}));

    s_poolToSendTo[_chainSelector] = _pool;

    emit ParentPool_PoolReceiverUpdated(_chainSelector, _pool);
  }

  /**
   * @notice Function to set the Cap of the Master pool.
   * @param _newCap The new Cap of the pool
   */
  function setPoolCap(uint256 _newCap) external payable onlyOwner {
    s_maxDeposit = _newCap;

    emit ParentPool_MasterPoolCapUpdated(_newCap);
  }

  function setDonHostedSecretsSlotId(uint8 _slotId) external payable onlyOwner {
    s_donHostedSecretsSlotId = _slotId;
  }

  function setDonHostedSecretsVersion(uint64 _version) external payable onlyOwner {
    s_donHostedSecretsVersion = _version;
  }

  function setHashSum(bytes32 _hashSum) external payable onlyOwner {
    s_hashSum = _hashSum;
  }

  function setEthersHashSum(bytes32 _ethersHashSum) external payable onlyOwner {
    s_ethersHashSum = _ethersHashSum;
  }

  /**
   * @notice Function to remove Cross-chain address disapproving transfers
   * @param _chainSelector the CCIP chainSelector for the specific chain
   */
  function removePoolsFromListOfSenders(uint64 _chainSelector) external payable onlyOwner {
    for (uint256 i; i < s_poolsToDistribute.length; ) {
      if (s_poolsToDistribute[i].chainSelector == _chainSelector) {
        s_poolsToDistribute[i] = s_poolsToDistribute[s_poolsToDistribute.length - 1];
        s_poolsToDistribute.pop();
        delete s_poolToSendTo[_chainSelector];
      }
      unchecked {
        ++i;
      }
    }
    emit ParentPool_ChainAndAddressRemoved(_chainSelector);
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
      IStorage.Transaction memory transaction = IOrchestrator(i_infraProxy).getTransactionsInfo(any2EvmMessage.messageId);

      if ((transaction.ccipMessageId == any2EvmMessage.messageId && transaction.isConfirmed == false) || transaction.ccipMessageId == 0) {
        i_USDC.safeTransfer(_user, amountMinusFees);
        //We don't subtract it here because the loan was not performed. And the value is not summed into the `s_loanInUse` variable.
      } else {
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

    for (uint256 i; i < _numberOfPools; ) {
      IParentPool.Pools memory pool = s_poolsToDistribute[i];

      Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), _amountToDistribute, pool.poolAddress);

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

  function _buildCCIPMessage(
    address _token,
    uint256 _amount,
    address _poolAddress
  ) internal view returns (Client.EVM2AnyMessage memory) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

    return
      Client.EVM2AnyMessage({
        receiver: abi.encode(_poolAddress),
        data: abi.encode(address(0), address(0), 0), //Here the 1° address is (0) because this is the Parent Pool and we never send to withdraw in another place.
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 350_000})),
        feeToken: address(i_linkToken)
      });
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
    IParentPool.CLFRequest storage request = s_requests[requestId];

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

  function getPendingWithdrawRequest(address _liquidityProvider) external view returns (IParentPool.WithdrawRequests memory) {
    return s_pendingWithdrawRequests[_liquidityProvider];
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
  function _updateDepositInfoAndMintLPTokens(
    address _liquidityProvider,
    uint256 _lpSupplyBeforeRequest,
    uint256 _usdcDeposited,
    uint256 _totalUSDCCrossChain
  ) private {
    //_totalUSDCCrossChain == the sum of all chains balance + commits

    uint256 crossChainBalanceConverted = _convertToLPTokenDecimals(_totalUSDCCrossChain);
    uint256 amountDepositedConverted = _convertToLPTokenDecimals(_usdcDeposited);

    //N° lpTokens = (((Total USDC Liq + user deposit) * Total sToken) / Total USDC Liq) - Total sToken
    //If less than ALLOWED, means it's zero.
    uint256 lpTokensToMint = _lpSupplyBeforeRequest > ALLOWED
      ? (((crossChainBalanceConverted + amountDepositedConverted) * _lpSupplyBeforeRequest) / crossChainBalanceConverted) - _lpSupplyBeforeRequest
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
    uint256 numberOfPools = s_poolsToDistribute.length;
    uint256 totalCrossChainBalance = _totalUSDCCrossChain + i_USDC.balanceOf(address(this)) + s_loansInUse;

    //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
    uint256 amountToWithdraw = (((_convertToLPTokenDecimals(totalCrossChainBalance) * _lpToBurn) * PRECISION_HANDLER) / _lpSupplyBeforeRequest) /
      PRECISION_HANDLER;

    uint256 amountToWithdrawWithUsdcDecimals = _convertToUSDCTokenDecimals(amountToWithdraw);

    IParentPool.WithdrawRequests memory request = IParentPool.WithdrawRequests({
      amountEarned: amountToWithdrawWithUsdcDecimals,
      amountToBurn: _lpToBurn,
      amountToRequest: amountToWithdrawWithUsdcDecimals / (numberOfPools + 1), //Cross-chain Pools + MasterPool
      amountToReceive: (amountToWithdrawWithUsdcDecimals * numberOfPools) / (numberOfPools + 1), //The portion of the money that is not on MasterPool
      token: address(i_USDC),
      deadline: block.timestamp + WITHDRAW_DEADLINE //6days & 22h
    });

    s_withdrawRequests = s_withdrawRequests + amountToWithdrawWithUsdcDecimals / (numberOfPools + 1);

    s_pendingWithdrawRequests[_liquidityProvider] = request;
    i_automation.addPendingWithdrawal(_liquidityProvider);

    emit ParentPool_RequestUpdated(_liquidityProvider);
  }

  function _calculateDepositTransactionFee(uint256 _amountToDistribute) internal view returns(uint256 _totalUSDCCost){
    uint256 numberOfPools = s_poolsToDistribute.length;
    uint256 costOfLinkForLiquidityDistribution;
    uint256 premiumFee = Orchestrator(i_infraProxy).clfPremiumFees(BASE_CHAIN_SELECTOR);
    uint256 lastNativeUSDCRate = Orchestrator(i_infraProxy).s_latestNativeUsdcRate();
    uint256 lastLinkUSDCRate = Orchestrator(i_infraProxy).s_latestLinkUsdcRate();
    uint256 lastBaseGasPrice = tx.gasprice; //Orchestrator(i_infraProxy).s_lastGasPrices(BASE_CHAIN_SELECTOR);

    for(uint256 i; i < numberOfPools; ){
      IParentPool.Pools memory pool = s_poolsToDistribute[i];
      Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), (_amountToDistribute / (numberOfPools+1)), pool.poolAddress);

      //Link cost for all transactions
      costOfLinkForLiquidityDistribution += IRouterClient(i_ccipRouter).getFee(pool.chainSelector, evm2AnyMessage);
      unchecked {
        ++i;
      }
    }

    //_totalUSDCCost
    //    Pools.length x Calls to distribute liquidity
    //    1x Functions request sent
    //    1x Callback Writing to storage
    _totalUSDCCost = ((costOfLinkForLiquidityDistribution + premiumFee) * lastLinkUSDCRate) + ((WRITE_FUNCTIONS_COST * lastBaseGasPrice) * lastNativeUSDCRate);
  }

  function _calculateWithdrawTransactionsFee(uint256 _amountToReceive) internal view returns(uint256 _totalUSDCCost){
    uint256 numberOfPools = s_poolsToDistribute.length;
    uint256 premiumFee = Orchestrator(i_infraProxy).clfPremiumFees(BASE_CHAIN_SELECTOR);
    uint256 baseLastGasPrice = tx.gasprice; //Orchestrator(i_infraProxy).s_lastGasPrices(BASE_CHAIN_SELECTOR);
    uint256 lastNativeUSDCRate = Orchestrator(i_infraProxy).s_latestNativeUsdcRate();
    uint256 lastLinkUSDCRate = Orchestrator(i_infraProxy).s_latestLinkUsdcRate();

    uint256 costOfLinkForLiquidityWithdraw;
    uint256 costOfCCIPSendToPoolExecution;

    for(uint256 i; i < numberOfPools; ){
      IParentPool.Pools memory pool = s_poolsToDistribute[i];
      Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(address(i_USDC), _amountToReceive, address(this));

      //Link cost for all transactions
      costOfLinkForLiquidityWithdraw += IRouterClient(i_ccipRouter).getFee(BASE_CHAIN_SELECTOR, evm2AnyMessage); //here the chainSelector must be Base's?
      //USDC costs for all writing from the above transactions
      costOfCCIPSendToPoolExecution += Orchestrator(i_infraProxy).s_lastGasPrices(pool.chainSelector) * WRITE_FUNCTIONS_COST;
      unchecked {
        ++i;
      }
    }
    
    // _totalUSDCCost ==
    //    2x Functions Calls - Link Cost
    //    Pools.length x Calls - Link Cost
    //    Base's gas Cost of callback
    //    Pools.length x Calls to ccipSendToPool Child Pool function
    //  Automation Costs?
    //    SLOAD - 800
    //    ++i - 5
    //    Comparing = 3
    //    STORE - 5_000
    //    Array Reduction - 5_000
    //    gasOverhead - 80_000
    //    Nodes Premium - 50%
    uint256 arrayLength = i_automation.getPendingWithdrawRequestsLength();

    uint256 automationCost = (((ITERATION_COSTS * arrayLength) + ARRAY_MANIPULATION + AUTOMATION_OVERHEARD) * NODE_PREMIUM) / 100;
    _totalUSDCCost = (((premiumFee * 2) + costOfLinkForLiquidityWithdraw + automationCost) * lastLinkUSDCRate) + ((WRITE_FUNCTIONS_COST * baseLastGasPrice) * lastNativeUSDCRate) + costOfCCIPSendToPoolExecution;
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

  function getMaxCap() external view returns (uint256 _maxCap) {
    _maxCap = s_maxDeposit;
  }

  function getUsdcInUse() external view returns (uint256 _usdcInUse) {
    _usdcInUse = s_loansInUse;
  }

  // TODO: Remove this function after tests
  function deletePendingWithdrawRequest(address _liquidityProvider) external isProxy onlyOwner {
    delete s_pendingWithdrawRequests[_liquidityProvider];
  }
}
