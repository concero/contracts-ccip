// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {IConceroPool} from "contracts/Interfaces/IConceroPool.sol";

import {ConceroAutomation} from "./ConceroAutomation.sol";
import {LPToken} from "./LPToken.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the caller is not authorized
error ConceroPool_Unauthorized();
///@notice error emitted when the balance is not sufficient
error ConceroPool_InsufficientBalance();
///@notice error emitted when the receiver is the address(0)
error ConceroPool_InvalidAddress();
///@notice error emitted when the CCIP message sender is not allowed.
error ConceroPool_SenderNotAllowed(address _sender);
///@notice error emitted when an attempt to create a new request is made while other is still active.
error ConceroPool_ActiveRequestNotFulfilledYet();
///@notice error emitted when an attempt to send value to a not allowed receiver is made
error ConceroPool_DestinationNotAllowed();
///@notice error emitted when the contract doesn't have enough link balance
error ConceroPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when a LP try to deposit liquidity on the contract without pools
error ConceroPool_ThereIsNoPoolToDistribute();
///@notice emitted in depositLiquidity when the input amount is not enough
error ConceroPool_EmptyDepositedIsNotAllowed(uint256 amount);
///@notice emitted in withdrawLiquidity when the amount to withdraws is bigger than the balance
error ConceroPool_AmountNotAvailableYet(uint256 amountAvailable);
///@notice emitted in depositLiquidity when the input token is not allowed
error ConceroPool_TokenNotAllowed(address token);
///@notice error emitted when the caller is not the messenger
error ConceroPool_NotMessenger(address caller);
///@notice error emitted when the chain selector input is invalid
error ConceroPool_ChainNotAllowed(uint64 chainSelector);
///@notice error emitted when the caller is not the Orchestrator
error ConceroPool_ItsNotAnOrchestrator(address caller);

contract ConceroPool is CCIPReceiver, Ownable {
  using SafeERC20 for IERC20;

  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  ///@notice `ccipSend` to distribute liquidity
  struct Pools {
    uint64 chainSelector;
    address poolAddress;
  }

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///@notice variable to store the total value deposited
  uint256 private s_usdcPoolReserve;
  ///@notice variable to store the value that will be temporary used by Chainlink Functions
  uint256 private s_commit;
  ///@notice variable to store the amount distributed to child pools
  uint256 private s_valueDistributed; //@audit need to be decrease when a withdraw is processed.
  ///@notice variable to store the concero contract address
  address private s_concero;

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Chainlink Link Token interface
  LinkTokenInterface private immutable i_linkToken;
  ///@notice Chainlink CCIP Router
  IRouterClient private immutable i_router;
  ///@notice immutable variable to store the USDC address.
  IERC20 immutable i_USDC;
  ///@notice Pool liquidity token
  LPToken public immutable lp;
  ///@notice Concero Automation contract
  ConceroAutomation private immutable automation;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Magic Number Removal
  uint256 private constant ALLOWED = 1;
  uint256 private constant USDC_DECIMALS = 10 ** 6;
  uint256 private constant LP_TOKEN_DECIMALS = 10 ** 18;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  Pools[] poolsToDistribute;

  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) internal s_messengerAddresses;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainId => mapping(address poolAddress => uint256)) public s_poolToReceiveFrom;
  ///@notice Mapping to keep track of Liquidity Providers withdraw requests
  mapping(address _liquidityProvider => IConceroPool.WithdrawRequests) public s_pendingWithdrawRequests;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when the Messenger address is updated
  event ConceroPool_MessengerUpdated(address messengerAddress, uint256 allowed);
  ///@notice event emitted when a Concero pool is added
  event ConceroPool_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a allowed Cross-chain contract is updated
  event ConceroPool_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256 isAllowed);
  ///@notice event emitted when a new withdraw request is made
  event ConceroPool_WithdrawRequest(address caller, IERC20 token, uint256 deadline, uint256 amount);
  ///@notice event emitted when a value is withdraw from the contract
  event ConceroPool_Withdrawn(address to, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain tx is received.
  event ConceroPool_CCIPReceived(bytes32 indexed ccipMessageId, uint64 srcChainSelector, address sender, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain message is sent.
  event ConceroPool_MessageSent(bytes32 messageId, uint64 destinationChainSelector, address receiver, address linkToken, uint256 fees);
  ///@notice event emitted in depositLiquidity when a deposit is successful executed
  event ConceroPool_SuccessfulDeposited(address liquidityProvider, uint256 _amount, IERC20 _token);
  ///@notice event emitted in setConceroContract when the address is emitted
  event ConceroPool_ConceroContractUpdated(address concero);

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice CCIP Modifier to check Chains And senders
   * @param _chainSelector Id of the source chain of the message
   * @param _sender address of the sender contract
   */
  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (s_poolToReceiveFrom[_chainSelector][_sender] != ALLOWED) revert ConceroPool_SenderNotAllowed(_sender);
    _;
  }

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (s_messengerAddresses[msg.sender] != ALLOWED) revert ConceroPool_NotMessenger(msg.sender);
    _;
  }

  /**
   * @notice CCIP Modifier to check receivers for a specific chain
   * @param _chainSelector Id of the destination chain
   */
  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_poolToSendTo[_chainSelector] == address(0)) revert ConceroPool_ChainNotAllowed(_chainSelector);
    _;
  }

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  receive() external payable {}

  constructor(address _link, address _ccipRouter, address _usdc, address _lpToken, address _automation) CCIPReceiver(_ccipRouter) {
    i_linkToken = LinkTokenInterface(_link);
    i_router = IRouterClient(_ccipRouter);
    i_USDC = IERC20(_usdc);
    lp = LPToken(_lpToken);
    automation = ConceroAutomation(_automation);
  }

  ////////////////////////
  ///EXTERNAL FUNCTIONS///
  ////////////////////////
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
    s_poolToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

    emit ConceroPool_ConceroSendersUpdated(_chainSelector, _contractAddress, _isAllowed);
  }

  /**
   * @notice function to manage the Cross-chain ConceroPool contracts
   * @param _chainSelector chain identifications
   * @param _pool address of the Cross-chain ConceroPool contract
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   * @dev this functions is used on ConceroPool.sol
   */
  function setConceroPoolReceiver(uint64 _chainSelector, address _pool) external payable onlyOwner {
    poolsToDistribute.push(Pools({chainSelector: _chainSelector, poolAddress: _pool}));

    s_poolToSendTo[_chainSelector] = _pool;

    emit ConceroPool_PoolReceiverUpdated(_chainSelector, _pool);
  }

  /**
   * @notice Function to update Concero Messenger Addresses
   * @param _walletAddress the messenger address
   * @param _approved 1 == Approved | Any other value disapproved
   */
  function setConceroMessenger(address _walletAddress, uint256 _approved) external onlyOwner {
    if (_walletAddress == address(0)) revert ConceroPool_InvalidAddress();

    s_messengerAddresses[_walletAddress] = _approved;

    emit ConceroPool_MessengerUpdated(_walletAddress, _approved);
  }

  function setConceroContract(address _concero) external onlyOwner{
    s_concero = _concero;

    emit ConceroPool_ConceroContractUpdated(_concero);
  }

  /**
   * @notice Function to Distribute Liquidity accross Concero Pools
   * @param _destinationChainSelector Chain Id of the chain that will receive the amount
   * @param _token  address of the token to be sent
   * @param _amount amount of the token to be sent
   */
  function ccipSendToPool(
    uint64 _destinationChainSelector,
    address _token,
    uint256 _amount
  ) external onlyMessenger onlyAllowListedChain(_destinationChainSelector) returns (bytes32 messageId) {
    if (s_poolToSendTo[_destinationChainSelector] == address(0)) revert ConceroPool_DestinationNotAllowed();
    if (_amount > s_usdcPoolReserve) revert ConceroPool_InsufficientBalance();

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: _token, amount: _amount});

    tokenAmounts[0] = tokenAmount;

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(s_poolToSendTo[_destinationChainSelector]),
      data: "",
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
      feeToken: address(i_linkToken)
    });

    uint256 fees = i_router.getFee(_destinationChainSelector, evm2AnyMessage);

    if (fees > i_linkToken.balanceOf(address(this))) revert ConceroPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

    IERC20(_token).safeApprove(address(i_router), _amount);
    i_linkToken.approve(address(i_router), fees);

    emit ConceroPool_MessageSent(messageId, _destinationChainSelector, s_poolToSendTo[_destinationChainSelector], address(i_linkToken), fees);

    messageId = i_router.ccipSend(_destinationChainSelector, evm2AnyMessage);
  }

  /**
   * @notice function to the Concero Orchestrator contract take loans
   * @param _token address of the token being loaned
   * @param _amount being loaned
   * @param _receiver address of the user that will receive the amount
   * @dev only the Orchestrator contract should be able to call this function
   * @dev for ether transfer, the _receiver need to be known and trusted
   */
  function orchestratorLoan(address _token, uint256 _amount, address _receiver) external {
    if (msg.sender != s_concero) revert ConceroPool_ItsNotAnOrchestrator(msg.sender);
    if (_receiver == address(0)) revert ConceroPool_InvalidAddress();

    s_commit = s_commit + _amount;

    //@audit need to check if we can remove this check. If I am not mistaken, the SafeERC checks for balance and revert if it's bigger than balance.
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroPool_InsufficientBalance();

    IERC20(_token).safeTransfer(_receiver, _amount);
  }

  /**
   * @notice Function for user to deposit liquidity of allowed tokens
   * @param _amount the amount to be deposited
   */
  function depositLiquidity(uint256 _amount) external {
    if (_amount < 1 * USDC_DECIMALS) revert ConceroPool_EmptyDepositedIsNotAllowed(_amount);

    uint256 lpTokenSupply = lp.totalSupply();
    uint256 numberOfPools = poolsToDistribute.length + 1;
    uint256 usdcReserve = s_usdcPoolReserve;

    if (numberOfPools < 2) revert ConceroPool_ThereIsNoPoolToDistribute();

    //N° lpTokens = (((Total Liq + user deposit) * Total sToken) / Total USDC Liq) - Total sToken
    uint256 lpTokensToMint = lpTokenSupply >= ALLOWED
    ? ((adjustUSDCAmount((usdcReserve + _amount)) * lpTokenSupply) / adjustUSDCAmount(usdcReserve)) - lpTokenSupply
    : adjustUSDCAmount(_amount);

    s_usdcPoolReserve = usdcReserve + _amount;

    emit ConceroPool_SuccessfulDeposited(msg.sender, _amount, i_USDC);

    i_USDC.safeTransferFrom(msg.sender, address(this), _amount);

    lp.mint(msg.sender, lpTokensToMint);

    if(s_usdcPoolReserve - (s_valueDistributed * numberOfPools) > 30 * USDC_DECIMALS){
      uint256 amountToDistribute = (s_usdcPoolReserve - (s_valueDistributed * numberOfPools)) / numberOfPools;

      _ccipSend(numberOfPools, amountToDistribute);
    }
  }

  /**
   * @notice Function to allow Liquidity Providers to start the Withdraw of their USDC deposited
   * @param _lpAmount the amount of lp token the user wants to burn to get USDC back.
   */
  function startWithdrawal(uint256 _lpAmount) external {
    if(lp.balanceOf(msg.sender) < _lpAmount) revert ConceroPool_InsufficientBalance();
    if(s_pendingWithdrawRequests[msg.sender].amountToBurn > 0) revert ConceroPool_ActiveRequestNotFulfilledYet();

    //We calculate the total amount to be withdraw. Using 18 decimals to reduce loss of precision
    ///@audit need to convert to 18 dec and return back to 6 dec

    //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_DEPOSIT / TOTAL_LP)
    uint256 amountToWithdraw = s_usdcPoolReserve * (_lpAmount / lp.totalSupply());

    IConceroPool.WithdrawRequests memory request = IConceroPool.WithdrawRequests({
      amount: amountToWithdraw,
      amountToBurn: _lpAmount,
      receivedAmount: 0,
      token: address(i_USDC),
      sender: msg.sender,
      deadline: block.timestamp + 597_600 //6days & 22h
    });

    automation.addPendingWithdrawal(request);
    s_pendingWithdrawRequests[msg.sender] = request;

    emit ConceroPool_WithdrawRequest(msg.sender, i_USDC, block.timestamp + 597_600, amountToWithdraw);
  }

  function completeWithdrawal() external {
    IConceroPool.WithdrawRequests memory withdraw = s_pendingWithdrawRequests[msg.sender];
    if(withdraw.receivedAmount < withdraw.amount) revert ConceroPool_AmountNotAvailableYet(withdraw.receivedAmount);
    //@audit must improve this check, it will revert if the balance is less than the usage
    if (withdraw.amount > i_USDC.balanceOf(address(this)) - s_commit) revert ConceroPool_InsufficientBalance();

    s_usdcPoolReserve = s_usdcPoolReserve - withdraw.amount;
    delete s_pendingWithdrawRequests[msg.sender];

    emit ConceroPool_Withdrawn(msg.sender, address(i_USDC), withdraw.amount);

    IERC20(lp).safeTransferFrom(msg.sender, address(this), withdraw.amountToBurn);

    lp.burn(withdraw.amountToBurn);

    i_USDC.safeTransfer(msg.sender, withdraw.amount);
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
    (address _liquidityProvider, uint256 receivedFee) = abi.decode(any2EvmMessage.data, (address,uint256));

    if (receivedFee > 0) {
      //compound the transaction fee on totalAmount
      s_usdcPoolReserve = s_usdcPoolReserve + receivedFee;
      //subtract the amount from the committed total amount
      s_commit = s_commit - (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);
    } else if (_liquidityProvider != address(0)){
      //update the corresponding withdraw request
      s_pendingWithdrawRequests[_liquidityProvider].receivedAmount = s_pendingWithdrawRequests[_liquidityProvider].receivedAmount + any2EvmMessage.destTokenAmounts[0].amount;
    }

    emit ConceroPool_CCIPReceived(
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
      Pools memory pool = poolsToDistribute[i];

      Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
        receiver: abi.encode(pool.poolAddress),
        data: "",
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
        feeToken: address(i_linkToken)
      });

      uint256 fees = i_router.getFee(pool.chainSelector, evm2AnyMessage);

      if (fees > i_linkToken.balanceOf(address(this))) revert ConceroPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

      i_USDC.safeApprove(address(i_router), _amountToDistribute);
      i_linkToken.approve(address(i_router), fees);

      emit ConceroPool_MessageSent(messageId, pool.chainSelector, pool.poolAddress, address(i_linkToken), fees);

      messageId = i_router.ccipSend(pool.chainSelector, evm2AnyMessage);

      unchecked {
        ++i;
      }
    }
  }

  ///////////////
  /// PRIVATE ///
  ///////////////

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  function adjustUSDCAmount(uint256 _usdcAmount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_usdcAmount * LP_TOKEN_DECIMALS ) / USDC_DECIMALS;
  }
}
