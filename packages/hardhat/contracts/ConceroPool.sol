// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {Storage} from "./Libraries/Storage.sol";
import {LancaPool} from "./LancaPool.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the caller is not authorized
error ConceroPool_Unauthorized();
///@notice error emitted when the balance is not sufficient
error ConceroPool_InsufficientBalance();
///@notice error emitted when the transfer revert
error ConceroPool_TransferFailed();
///@notice error emitted when the user input an unsupported token
error ConceroPool_TokenNotSupported();
///@notice error emitted when the caller is not an Orchestrator
error ConceroPool_ItsNotAnOrchestrator(address caller);
///@notice error emitted when the receiver is the address(0)
error ConceroPool_InvalidAddress();
///@notice error emitted when the CCIP message sender is not allowed.
error ConceroPool_SenderNotAllowed(address _sender);
///@notice error emitted when an attempt to create a new request is made while other is still active.
error ConceroPool_ActivRequestNotFulfilledYet();
///@notice error emitted when an attempt to send value to a not allowed receiver is made
error ConceroPool_DestinationNotAllowed();
///@notice error emitted when the contract doesn't have enought link balance
error ConceroPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when a LP try to deposit liquidity on the contract without pools
error ConceroPool_ThereIsNoPoolToDistribute();
///@notice emitted in depositLiquidty when the input amount is not enough
error ConceroPool_EmptyDepositedIsNotAllowed(uint256 amount);
///@notice emitted in withdrawLiquidity when the amount to withdras is bigger than the balance
error ConceroPool_LockPeriodNotEndedYet(uint256 releaseDate);
///@notice emitted in depositLiquidity when the input token is not allowed
error ConceroPool_TokenNotAllowed(address token);
///@notice error emitted when the caller is not the messenger
error ConceroPool_NotMessenger(address caller);
///@notice error emitted when the chain selector input is invalid
error ConceroPool_ChainNotAllowed(uint64 chainSelector);

contract ConceroPool is CCIPReceiver, Ownable {
  using SafeERC20 for IERC20;

  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  ///@notice User deposit lock period
  struct Deposit {
    uint256 amountDeposited;
    uint256 lpTokenMinted;
    bool isWithdrawable;
  }

  ///@notice ConceroPool Request
  struct WithdrawRequests {
    uint256 amount;
    uint256 amountToBurn;
    IERC20 token;
    address sender;
    uint256 deadline;
  }

  ///@notice `ccipSend` to distribute liquidity
  struct Pools {
    uint64 chainSelector;
    address poolAddress;
  }

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///@notice variable to store the total value deposited
  uint256 internal s_usdcPoolReserve;
  ///@notice variable to store the total amount of liquidity fees
  uint256 internal s_totalFees;
  ///@notice variable to store the value that will be temporary used by Chainlink Functions
  uint256 internal s_usdcUsageCLF;
  ///@notice variable to store the automation keeper address
  address internal s_AutomationKeeper;

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Chainlink Link Token interface
  LinkTokenInterface private immutable i_linkToken;
  ///@notice Chainlink CCIP Router
  IRouterClient private immutable i_router;
  ///@notice Immutable variable to hold proxy address
  address private immutable i_proxy;
  ///@notice Pool sTaking token
  LancaPool public immutable lanca;
  ///@notice Address os USDC for the deployed chain
  IERC20 private immutable USDC;

  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Magic Number Removal
  uint256 private constant ALLOWED = 1;
  uint256 private constant USDC_DECIMALS = 10 ** 6;
  uint256 private constant LANCA_DECIMALS = 10 ** 18;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array of Pools to receive Liquidity through `ccipSend` function
  Pools[] poolsToDistribute;
  WithdrawRequests[] withdrawRequests;

  ///@notice Mapping to keep track of messenger addresses
  mapping(address messenger => uint256 allowed) internal s_messengerAddresses;
  ///@notice Mapping to keep track of allowed pool receiver
  mapping(uint64 chainId => address pool) public s_poolToSendTo;
  ///@notice Mapping to keep track of allowed pool senders
  mapping(uint64 chainId => mapping(address poolAddress => uint256)) public s_poolToReceiveFrom;
  ///@notice Mapping to store the data structure for deposits
  mapping(address user => Deposit[]) public s_depositRegister;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when the Messenger address is updated
  event ConceroPool_MessengerUpdated(address messengerAddress, uint256 allowed);
  ///@notice event emitted when a Concero pool is added
  event ConceroPool_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when an approved sender is updated
  event ConceroPool_ApprovedSenderUpdated(address token, address indexed newSender);
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
  ///@notice event emitted when a Liquidity Provider add liquidity to our pool
  event ConceroPool_Deposited(address token, address liquidityProvider, uint256 amount);
  ///@notice event emitted when the orchestrator
  event ConceroPool_OrchestratorContractUpdated(address orchestrator);
  ///@notice event emitted in depositLiquidty when a deposit is successful executed
  event ConceroPool_SuccessfullDeposited(address liquidityProvider, uint256 _amount, IERC20 _token);
  ///@notice event emitted when the Automation Keeper is updated;
  event ConceroPool_KeeperUpdated(address keeper);

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

  constructor(address _link, address _ccipRouter, address _proxy, address _usdcAddress) CCIPReceiver(_ccipRouter) {
    i_linkToken = LinkTokenInterface(_link);
    i_router = IRouterClient(_ccipRouter);
    i_proxy = _proxy;
    USDC = IERC20(_usdcAddress);
    lanca = new LancaPool("Lanca Pool", "sLanca");
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
    Pools memory pool = Pools({chainSelector: _chainSelector, poolAddress: _pool});

    poolsToDistribute.push(pool);
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

  /**
   * @notice Function to update automation Keeper
   * @param _keeper the address of keeper
   */
  function setAutomationKeeper(address _keeper) external onlyOwner{
    s_AutomationKeeper = _keeper;

    emit ConceroPool_KeeperUpdated(_keeper);
  }

  /**
   * @notice Function for user to deposit liquidity of allowed tokens
   * @param _amount the amount to be deposited
   */
  function depositLiquidity(uint256 _amount) external {
    if (_amount < 1 * USDC_DECIMALS) revert ConceroPool_EmptyDepositedIsNotAllowed(_amount);

    uint256 lpTokenSupply = lanca.totalSupply();

    //N° lpTokens = (((Total Liq + user deposit) * Total sToken) / Total USDC Liq) - Total sToken
    uint256 lpTokensToMint = lpTokenSupply >= ALLOWED
    ? ((adjustUSDCAmount((s_usdcPoolReserve + _amount)) * lpTokenSupply) / adjustUSDCAmount(s_usdcPoolReserve)) - lpTokenSupply
    : adjustUSDCAmount(_amount);

    s_usdcPoolReserve = s_usdcPoolReserve + _amount;

    s_depositRegister[msg.sender].push(Deposit({amountDeposited: _amount, lpTokenMinted: lpTokensToMint, isWithdrawable: false}));

    emit ConceroPool_SuccessfullDeposited(msg.sender, _amount, USDC);

    USDC.safeTransferFrom(msg.sender, address(this), _amount);

    lanca.mint(msg.sender, lpTokensToMint);
  }

  /**
   * @notice Function to allow Liquidity Providers to Withdraw their USDC deposited
   * @param _index the array index of the specific lock to withdraw
   */
  function withdrawLiquidityRequest(uint256 _index) external {
    Deposit memory register = s_depositRegister[msg.sender][_index];

    //We calculate the total amount to be withdraw. Using 18 decimals to reduce loss of precision
    ///@audit need to convert to 18 dec and return back to 6 dec

    //USDC_WITHDRAWABLE = POOL_BALANCE x (LP_DEPOSIT / TOTAL_LP)
    uint256 amountToWithdraw = s_usdcPoolReserve * (register.lpTokenMinted / lanca.totalSupply());

    withdrawRequests.push(WithdrawRequests({
      amount: amountToWithdraw,
      amountToBurn: register.lpTokenMinted,
      token: USDC,
      sender: msg.sender,
      deadline: block.timestamp + 7 days
    }));

    emit ConceroPool_WithdrawRequest(msg.sender, USDC, block.timestamp + 7 days, amountToWithdraw);
    //@audit YET TO FINISH
  }

  function claimWithdraw() external {
    //@audit YET TO FINISH
    uint256 requestsArrayLength = withdrawRequests.length;

    for(uint256 i; i < requestsArrayLength; ++i){
      uint256 amount = withdrawRequests[i].amount;
      uint256 amountToBurn = withdrawRequests[i].amountToBurn;

      if(withdrawRequests[i].sender == msg.sender){

        //@audit must improve this check, it will revert if the balance is less than the usage
        if (amount > USDC.balanceOf(address(this)) - s_usdcUsageCLF) revert ConceroPool_InsufficientBalance();

        s_usdcPoolReserve = s_usdcPoolReserve - amount;

        IERC20(lanca).safeTransferFrom(msg.sender, address(this), amountToBurn);

        lanca.burn(amountToBurn);

        USDC.safeTransfer(msg.sender, amount);
      }
    }
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
    if (msg.sender != i_proxy) revert ConceroPool_ItsNotAnOrchestrator(msg.sender);
    if (_receiver == address(0)) revert ConceroPool_InvalidAddress();
    //@audit need to check if we can remove this check. If I am not mistaken, the SafeERC checks for balance and revert if it's bigger than balance.
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroPool_InsufficientBalance();

    IERC20(_token).safeTransfer(_receiver, _amount);
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
    address receivedToken = any2EvmMessage.destTokenAmounts[0].token;

    if (any2EvmMessage.data.length > 0) {
      uint256 receivedAmount = abi.decode(any2EvmMessage.data, (uint256));

      s_totalFees = s_totalFees + receivedAmount;
    } else {
      //@audit What we will do here?
    }

    emit ConceroPool_CCIPReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector,
      abi.decode(any2EvmMessage.sender, (address)),
      any2EvmMessage.destTokenAmounts[0].token,
      any2EvmMessage.destTokenAmounts[0].amount
    );
  }

  ///////////////
  /// PRIVATE ///
  ///////////////

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////
  function adjustUSDCAmount(uint256 _usdcAmount) internal pure returns (uint256 _adjustedAmount) {
    _adjustedAmount = (_usdcAmount * LANCA_DECIMALS) / USDC_DECIMALS;
  }
}
