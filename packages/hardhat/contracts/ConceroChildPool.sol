// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ChildPoolStorage} from "contracts/Libraries/ChildPoolStorage.sol";
import {IStorage} from "./Interfaces/IStorage.sol";
import {IOrchestrator} from "./Interfaces/IOrchestrator.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the balance is not sufficient
error ConceroChildPool_InsufficientBalance();
///@notice error emitted when the contract doesn't have enough link balance
error ConceroChildPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when the caller is not the Orchestrator
error ConceroChildPool_CallerIsNotTheProxy(address delegatedCaller);
///@notice error emitted when a not-concero address call takeLoan
error ConceroChildPool_CallerIsNotConcero(address caller);
///@notice error emitted when the receiver is the address(0)
error ConceroChildPool_InvalidAddress();
///@notice error emitted when the caller is a non-messenger address
error ConceroChildPool_NotMessenger(address caller);
///@notice error emitted when the caller is not the owner of the contract
error ConceroChildPool_NotContractOwner();
///@notice error emitted when the CCIP message sender is not allowed.
error ConceroChildPool_SenderNotAllowed(address sender);
///@notice error emitted if the array is empty.
error ConceroChildPool_ThereIsNoPoolToDistribute();
error ConceroChildPool_RequestAlreadyProceeded(bytes32 reqId);
error ConceroChildPool_WithdrawAlreadyPerformed();

contract ConceroChildPool is CCIPReceiver, ChildPoolStorage {
  using SafeERC20 for IERC20;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Magic Number Removal
  uint256 private constant ALLOWED = 1;

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice immutable variable to store Orchestrator Proxy
  address private immutable i_infraProxy;
  ///@notice Child Pool proxy address
  address private immutable i_childProxy;
  ///@notice Chainlink Link Token interface
  LinkTokenInterface private immutable i_linkToken;
  ///@notice immutable variable to store the USDC address.
  IERC20 private immutable i_USDC;
  ///@notice Contract Owner
  address immutable i_owner;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Cross-chain tx is received.
  event ConceroChildPool_CCIPReceived(bytes32 indexed ccipMessageId, uint64 srcChainSelector, address sender, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain message is sent.
  event ConceroChildPool_MessageSent(bytes32 messageId, uint64 destinationChainSelector, address receiver, address linkToken, uint256 fees);
  ///@notice event emitted in takeLoan when a loan is taken
  event ConceroChildPool_LoanTaken(address receiver, uint256 amount);
  ///@notice event emitted when a allowed Cross-chain contract is updated
  event ConceroChildPool_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256 isAllowed);
  ///@notice event emitted when a new pool is added
  event ConceroChildPool_PoolReceiverUpdated(uint64 chainSelector, address pool);
  ///@notice event emitted when a pool is removed
  event ConceroChildPool_ChainAndAddressRemoved(uint64 chainSelector);

  ///////////////
  ///MODIFIERS///
  ///////////////
  /**
   * @notice modifier to ensure if the function is being executed in the proxy context.
   */
  modifier isProxy() {
    if (address(this) != i_childProxy) revert ConceroChildPool_CallerIsNotTheProxy(address(this));
    _;
  }

  /**
   * @notice modifier to check if the caller is the an approved messenger
   */
  modifier onlyMessenger() {
    if (isMessenger(msg.sender) == false) revert ConceroChildPool_NotMessenger(msg.sender);
    _;
  }

  modifier onlyOwner() {
    if (msg.sender != i_owner) revert ConceroChildPool_NotContractOwner();
    _;
  }

  /**
   * @notice CCIP Modifier to check Chains And senders
   * @param _chainSelector Id of the source chain of the message
   * @param _sender address of the sender contract
   */
  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (s_contractsToReceiveFrom[_chainSelector][_sender] != ALLOWED) revert ConceroChildPool_SenderNotAllowed(_sender);
    _;
  }

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  receive() external payable {}

  constructor(address _orchestratorProxy, address _childProxy, address _link, address _ccipRouter, address _usdc, address _owner) CCIPReceiver(_ccipRouter) {
    i_infraProxy = _orchestratorProxy;
    i_childProxy = _childProxy;
    i_linkToken = LinkTokenInterface(_link);
    i_USDC = IERC20(_usdc);
    i_owner = _owner;
  }

  ////////////////////////
  ///EXTERNAL FUNCTIONS///
  ////////////////////////

  /**
   * @notice Function called by Messenger process withdraw calls
   * @param _chainSelector The destination chain selector will always be from Parent Pool
   * @param _liquidityProvider the LP that requested withdraw.
   * @param _amountToSend the amount to redistribute between pools.
   */
  function ccipSendToPool(uint64 _chainSelector, address _liquidityProvider, uint256 _amountToSend, bytes32 _withdrawId) external isProxy onlyMessenger {
    if (s_poolToSendTo[_chainSelector] == address(0)) revert ConceroChildPool_InvalidAddress();
    if (s_withdrawRequests[_withdrawId] == true) revert ConceroChildPool_WithdrawAlreadyPerformed();

    s_withdrawRequests[_withdrawId] = true;
    
    _ccipSend(_chainSelector, _liquidityProvider, _amountToSend);
  }

  /**
   * @notice Function called by Messenger to send USDC to a recently added pool.
   * @param _chainSelector The chain selector of the new pool
   * @param _amountToSend the amount to redistribute between pools.
   */
  function distributeLiquidity(uint64 _chainSelector, uint256 _amountToSend, bytes32 distributeLiquidityRequestId) external isProxy onlyMessenger {
    if (s_poolToSendTo[_chainSelector] == address(0)) revert ConceroChildPool_InvalidAddress();
    if (s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] != false) {
      revert ConceroChildPool_RequestAlreadyProceeded(distributeLiquidityRequestId);
    }
    s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] = true;
    _ccipSend(_chainSelector, address(0), _amountToSend);
  }

  /**
   * @notice helper function to remove and distribute liquidity when a pool is removed.
   * @dev this functions should be called only if there is no transaction being processed
   * @dev If Orchestrator took a loan and the money didn't rebalance yet, it will be left behind.
   */
  function liquidatePool(bytes32 distributeLiquidityRequestId) external isProxy onlyMessenger {
    if (s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] != false) {
      revert ConceroChildPool_RequestAlreadyProceeded(distributeLiquidityRequestId);
    }
    s_distributeLiquidityRequestProcessed[distributeLiquidityRequestId] = true;

    uint256 numberOfPools = s_poolChainSelectors.length;
    if (numberOfPools < ALLOWED) revert ConceroChildPool_ThereIsNoPoolToDistribute();

    uint256 amountToSentToEachPool = (i_USDC.balanceOf(address(this)) / numberOfPools) - 1;

    for (uint256 i; i < numberOfPools; ) {
      //This is a function to deal with adding&removing pools. So, the second param will always be address(0)
      _ccipSend(s_poolChainSelectors[i], address(0), amountToSentToEachPool);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice function to the Concero Orchestrator contract take loans
   * @param _token address of the token being loaned
   * @param _amount being loaned
   * @param _receiver address of the user that will receive the amount
   * @dev only the Orchestrator contract should be able to call this function
   * @dev for ether transfer, the _receiver need to be known and trusted
   */
  function takeLoan(address _token, uint256 _amount, address _receiver) external isProxy {
    if (msg.sender != i_infraProxy) revert ConceroChildPool_CallerIsNotConcero(msg.sender);
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroChildPool_InsufficientBalance();
    if (_receiver == address(0)) revert ConceroChildPool_InvalidAddress();

    s_loansInUse = s_loansInUse + _amount;

    IERC20(_token).safeTransfer(_receiver, _amount);

    emit ConceroChildPool_LoanTaken(_receiver, _amount);
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
  function setConceroContractSender(uint64 _chainSelector, address _contractAddress, uint256 _isAllowed) external payable isProxy onlyOwner {
    if (_contractAddress == address(0)) revert ConceroChildPool_InvalidAddress();
    s_contractsToReceiveFrom[_chainSelector][_contractAddress] = _isAllowed;

    emit ConceroChildPool_ConceroSendersUpdated(_chainSelector, _contractAddress, _isAllowed);
  }

  /**
   * @notice function to manage the Cross-chain ConceroPool contracts
   * @param _chainSelector chain identifications
   * @param _pool address of the Cross-chain ConceroPool contract
   * @dev only owner can call it
   * @dev it's payable to save some gas.
   */
  function setPools(uint64 _chainSelector, address _pool) external payable isProxy onlyOwner {
    if (s_poolToSendTo[_chainSelector] == _pool || _pool == address(0)) revert ConceroChildPool_InvalidAddress();

    s_poolChainSelectors.push(_chainSelector);
    s_poolToSendTo[_chainSelector] = _pool;

    emit ConceroChildPool_PoolReceiverUpdated(_chainSelector, _pool);
  }

  /**
   * @notice Function to remove Cross-chain address disapproving transfers
   * @param _chainSelector the CCIP chainSelector for the specific chain
   */
  function removePools(uint64 _chainSelector) external payable isProxy onlyOwner {
    for (uint256 i; i < s_poolChainSelectors.length; ) {
      if (s_poolChainSelectors[i] == _chainSelector) {
        s_poolChainSelectors[i] = s_poolChainSelectors[s_poolChainSelectors.length - 1];
        s_poolChainSelectors.pop();
        delete s_poolToSendTo[_chainSelector];
      }
      unchecked {
        ++i;
      }
    }

    emit ConceroChildPool_ChainAndAddressRemoved(_chainSelector);
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
    (, /*address liquidityProvider*/ address _user, uint256 receivedFee) = abi.decode(any2EvmMessage.data, (address, address, uint256));

    uint256 amountMinusFees = (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);

    //If receivedFee > 0, it means is user transaction. If receivedFee == 0, means it's a deposit from ParentPool
    if (receivedFee > 0) {
      IStorage.Transaction memory transaction = IOrchestrator(i_infraProxy).getTransactionsInfo(any2EvmMessage.messageId);

      if ((transaction.ccipMessageId == any2EvmMessage.messageId && transaction.isConfirmed == false) || transaction.ccipMessageId == 0) {
        i_USDC.safeTransfer(_user, amountMinusFees);
        //We don't subtract it here because the loan was not performed. And the value is not added into the `s_loanInUse` variable.
      } else {
        //subtract the amount from the committed total amount
        s_loansInUse = s_loansInUse - amountMinusFees;
      }
    }

    emit ConceroChildPool_CCIPReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector,
      abi.decode(any2EvmMessage.sender, (address)),
      any2EvmMessage.destTokenAmounts[0].token,
      any2EvmMessage.destTokenAmounts[0].amount
    );
  }

  /**
   * @notice Function to Distribute Liquidity across Concero Pools and process withdrawals
   * @param _liquidityProviderAddress The liquidity provider that requested Withdraw. If it's a rebalance, it will be address(0)
   * @param _amount amount of the token to be sent
   * @dev This function will sent the address of the user as data. This address will be used to update the mapping on ParentPool.
   * @dev when processing withdrawals, the _chainSelector will always be the index 0 of s_poolChainSelectors
   */
  function _ccipSend(uint64 _chainSelector, address _liquidityProviderAddress, uint256 _amount) internal onlyMessenger isProxy returns (bytes32 messageId) {
    if (_amount > i_USDC.balanceOf(address(this))) revert ConceroChildPool_InsufficientBalance();

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: address(i_USDC), amount: _amount});

    tokenAmounts[0] = tokenAmount;

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(s_poolToSendTo[_chainSelector]),
      data: abi.encode(_liquidityProviderAddress, address(0), 0), //0== lp fee. It will always be zero because here we are only processing withdraws
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
      feeToken: address(i_linkToken)
    });

    uint256 fees = IRouterClient(i_ccipRouter).getFee(_chainSelector, evm2AnyMessage);

    if (fees > i_linkToken.balanceOf(address(this))) revert ConceroChildPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

    i_USDC.approve(i_ccipRouter, _amount);
    i_linkToken.approve(i_ccipRouter, fees);

    emit ConceroChildPool_MessageSent(messageId, _chainSelector, s_poolToSendTo[_chainSelector], address(i_linkToken), fees);

    messageId = IRouterClient(i_ccipRouter).ccipSend(_chainSelector, evm2AnyMessage);
  }

  ///////////////////////////
  ///VIEW & PURE FUNCTIONS///
  ///////////////////////////

  /**
   * @notice Function to check if a caller address is an allowed messenger
   * @param _messenger the address of the caller
   */
  function isMessenger(address _messenger) internal pure returns (bool _isMessenger) {
    address[] memory messengers = new address[](4); //Number of messengers. To define.
    messengers[0] = 0x11111003F38DfB073C6FeE2F5B35A0e57dAc4715;
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
