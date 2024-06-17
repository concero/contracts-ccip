// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
error ConceroPool_ItsNotConcero(address caller);
///@notice error emitted when the caller is not the owner
error NotContractOwner();
///@notice error emitted when the owner tries to add an receiver that was already added.
error ConceroPool_DuplicatedAddress();

contract ConceroPool is CCIPReceiver {
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
  ///@notice immutable variable to store the USDC address.
  IERC20 immutable i_USDC;
  ///@notice Pool liquidity token
  LPToken public immutable i_lp;
  ///@notice Concero Automation contract
  ConceroAutomation private immutable i_automation;
  ///@notice Contract Owner
  address immutable i_owner;

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
  mapping(address messenger => uint256 allowed) public s_messengerAddresses;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainSelector => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainSelector => mapping(address poolAddress => uint256)) public s_contractsToReceiveFrom;
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
  event ConceroPool_WithdrawRequest(address caller, IERC20 token, uint256 deadline);
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
  ///@notice event emitted when a request is updated with the total USDC to withdraw
  event ConceroPool_RequestUpdated(address liquidityProvider);

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice CCIP Modifier to check Chains And senders
   * @param _chainSelector Id of the source chain of the message
   * @param _sender address of the sender contract
   */
  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (s_contractsToReceiveFrom[_chainSelector][_sender] != ALLOWED) revert ConceroPool_SenderNotAllowed(_sender);
    _;
  }

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (getMessengers(msg.sender) == false) revert ConceroPool_NotMessenger(msg.sender);
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

  modifier onlyOwner(){
    if(msg.sender != i_owner) revert NotContractOwner();
    _;
  }

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  receive() external payable {}

  constructor(address _link, address _ccipRouter, address _usdc, address _lpToken, address _automation, address _owner) CCIPReceiver(_ccipRouter){
    i_linkToken = LinkTokenInterface(_link);
    i_USDC = IERC20(_usdc);
    i_lp = LPToken(_lpToken);
    i_automation = ConceroAutomation(_automation);
    i_owner = _owner;
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
    //@audit let's add some address(0) checks?
    s_contractsToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

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
  function setPoolsToSend(uint64 _chainSelector, address _pool) external payable onlyOwner {
    if(s_poolToSendTo[_chainSelector] != address(0)) revert ConceroPool_DuplicatedAddress();
    //@audit let's add some address(0) checks?
    poolsToDistribute.push(Pools({chainSelector: _chainSelector, poolAddress: _pool}));

    s_poolToSendTo[_chainSelector] = _pool;

    emit ConceroPool_PoolReceiverUpdated(_chainSelector, _pool);
  }

  /**
   * @notice Function to remove Cross-chain address disapproving transfers
   * @param _chainSelector the CCIP chainSelector for the specific chain
   */
  function removePoolsFromListOfSenders(uint64 _chainSelector) external payable onlyOwner{
    uint256 arrayLength = poolsToDistribute.length;
    for(uint256 i; i < arrayLength; ) {
      if(poolsToDistribute[i].chainSelector == _chainSelector){
        poolsToDistribute[i] = poolsToDistribute[poolsToDistribute.length - 1];
        poolsToDistribute.pop();
        delete s_poolToSendTo[_chainSelector];
      }
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice function to add Concero Contract address to storage
   * @param _concero the address of Concero Contract
   * @dev The address will be use to control access on `orchestratorLoan`
   */
  function setConceroContract(address _concero) external payable onlyOwner{
    //@audit let's add some address(0) checks?
    s_concero = _concero;

    emit ConceroPool_ConceroContractUpdated(_concero);
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
    if (msg.sender != s_concero) revert ConceroPool_ItsNotConcero(msg.sender);
    if (_receiver == address(0)) revert ConceroPool_InvalidAddress();
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroPool_InsufficientBalance();

    s_commit = s_commit + _amount;

    IERC20(_token).safeTransfer(_receiver, _amount);
  }

  /**
   * @notice Function for user to deposit liquidity of allowed tokens
   * @param _amount the amount to be deposited
   */
  function depositLiquidity(uint256 _amount) external {
    //@audit We need to implement the CAP for deposits.
    //It will require a new storage variable to be updated at times.
    if (_amount < 1 * USDC_DECIMALS) revert ConceroPool_EmptyDepositedIsNotAllowed(_amount);

    uint256 lpTokenSupply = i_lp.totalSupply();
    uint256 numberOfPools = poolsToDistribute.length + 1;
    uint256 usdcReserve = s_usdcPoolReserve;

    if (numberOfPools < 2) revert ConceroPool_ThereIsNoPoolToDistribute();

    //N° lpTokens = (((Total Liq + user deposit) * Total sToken) / Total USDC Liq) - Total sToken
    //@audit PROBLEMs
    //1. We don't know how much usdc are in all pools in this moment. We can calculate over usdc_deposited. Without fees
    //2. By doing that, we will need to have another state variable to track fees a part from the total_usdc in MasterPool.
    //3. Or think in something different
    uint256 lpTokensToMint = lpTokenSupply >= ALLOWED
    ? ((_convertToLPTokenDecimals((usdcReserve + _amount)) * lpTokenSupply) / _convertToLPTokenDecimals(usdcReserve)) - lpTokenSupply
    : _convertToLPTokenDecimals(_amount);

    s_usdcPoolReserve = usdcReserve + _amount;

    emit ConceroPool_SuccessfulDeposited(msg.sender, _amount, i_USDC);

    i_USDC.safeTransferFrom(msg.sender, address(this), _amount);

    i_lp.mint(msg.sender, lpTokensToMint);

    //@audit PROBLEM
    //To limit the min amount that will initiate the cross-chain distribution,
    //we need to maintain an storage variable that will be updated every time
    //a new distribution occurs. So, we will always check how much each pool has,
    //and subtract by the amount on the MasterPool to check if the threshold is reached.
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
    if(i_lp.balanceOf(msg.sender) < _lpAmount) revert ConceroPool_InsufficientBalance();
    if(s_pendingWithdrawRequests[msg.sender].amountToBurn > 0) revert ConceroPool_ActiveRequestNotFulfilledYet();

    IConceroPool.WithdrawRequests memory request = IConceroPool.WithdrawRequests({
      amount: 0,
      amountToBurn: _lpAmount,
      receivedAmount: 0,
      token: address(i_USDC),
      sender: msg.sender,
      deadline: block.timestamp + 597_600 //6days & 22h
    });

    i_automation.addPendingWithdrawal(request);
    s_pendingWithdrawRequests[msg.sender] = request;

    emit ConceroPool_WithdrawRequest(msg.sender, i_USDC, block.timestamp + 597_600);
  }

  /**
   * @notice Function to updated cross-chain rewards will be paid to liquidity providers in the end of
   * withdraw period.
   * @param _liquidityProvider Liquidity Provider address to update info.
   * @param _totalUSDC USDC total amount
   * @dev This function must be called only by an allowed Messenger & must not revert
   */
  function updateUsdcAmountEarned(address _liquidityProvider, uint256 _totalUSDC) external onlyMessenger {
    IConceroPool.WithdrawRequests memory request = s_pendingWithdrawRequests[_liquidityProvider];

    //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_INPUT_AMOUNT / TOTAL_LP)
    uint256 amountToWithdraw = _convertToLPTokenDecimals(_totalUSDC) * (request.amountToBurn / i_lp.totalSupply());

    s_pendingWithdrawRequests[_liquidityProvider].amount = _convertToUSDCTokenDecimals(amountToWithdraw);

    emit ConceroPool_RequestUpdated(_liquidityProvider);
  }

  /**
   * @notice Function called to finalize the withdraw process.
   * @dev The msg.sender will be used to load the withdraw request data
   * if the request received the total amount requested from other pools,
   * the withdraw will be finalize. If not, it must revert
   */
  function completeWithdrawal() external {
    IConceroPool.WithdrawRequests memory withdraw = s_pendingWithdrawRequests[msg.sender];
    if(withdraw.receivedAmount < withdraw.amount) revert ConceroPool_AmountNotAvailableYet(withdraw.receivedAmount);

    //@audit must improve this check, it will revert if the balance is less than the usage
    if (withdraw.amount > i_USDC.balanceOf(address(this)) - s_commit) revert ConceroPool_InsufficientBalance();

    s_usdcPoolReserve = s_usdcPoolReserve - withdraw.amount;
    s_valueDistributed = s_valueDistributed - withdraw.amount;

    delete s_pendingWithdrawRequests[msg.sender];

    emit ConceroPool_Withdrawn(msg.sender, address(i_USDC), withdraw.amount);

    IERC20(i_lp).safeTransferFrom(msg.sender, address(this), withdraw.amountToBurn);

    i_lp.burn(withdraw.amountToBurn);

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
      //@audit receivedAmount will never be equal to the amount to withdrawal because the 1 portion of the total is already here.
      //Need to improve the condition logic
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

      uint256 fees = IRouterClient(i_ccipRouter).getFee(pool.chainSelector, evm2AnyMessage);

      if (fees > i_linkToken.balanceOf(address(this))) revert ConceroPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

      i_USDC.approve(address(i_ccipRouter), _amountToDistribute);
      i_linkToken.approve(address(i_ccipRouter), fees);

      emit ConceroPool_MessageSent(messageId, pool.chainSelector, pool.poolAddress, address(i_linkToken), fees);

      messageId = IRouterClient(i_ccipRouter).ccipSend(pool.chainSelector, evm2AnyMessage);

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
  /**
   * @notice Internal function to convert USDC Decimals to LP Decimals
   * @param _usdcAmount the amount of USDC
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToLPTokenDecimals(uint256 _usdcAmount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = _usdcAmount * (LP_TOKEN_DECIMALS - USDC_DECIMALS);
  }

  /**
   * @notice Internal function to convert LP Decimals to USDC Decimals
   * @param _lpAmount the amount of LP
   * @return _adjustedAmount the adjusted amount
   */
  function _convertToUSDCTokenDecimals(uint256 _lpAmount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = _lpAmount / (LP_TOKEN_DECIMALS - USDC_DECIMALS);
  }

  /**
   * @notice Function to check if a caller address is an allowed messenger
   * @param _messenger the address of the caller
   */
  function getMessengers(address _messenger) internal pure returns(bool isMessenger){
    address[] memory messengers = new address[](4); //Number of messengers. To define.
    messengers[0] = address(0);
    messengers[1] = address(0);
    messengers[2] = address(0);
    messengers[3] = address(0);

    for(uint256 i; i < messengers.length; ){
      if(_messenger == messengers[i]){
        return true;
      }
      unchecked{
        ++i;
      }
    }
    return false;
  }
}
