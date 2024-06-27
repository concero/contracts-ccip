// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

import {ChildStorage} from "contracts/Libraries/ChildStorage.sol";

import {IStorage} from "./Interfaces/IStorage.sol";

////////////////////////////////////////////////////////
//////////////////////// ERRORS ////////////////////////
////////////////////////////////////////////////////////
///@notice error emitted when the balance is not sufficient
error ConceroChildPool_InsufficientBalance();
///@notice error emitted when the contract doesn't have enough link balance
error ConceroChildPool_NotEnoughLinkBalance(uint256 linkBalance, uint256 fees);
///@notice error emitted when the caller is not the Orchestrator
error ConceroChildPool_CallerIsNotTheProxy(address delegatedCaller);
///@notice error emitted when a not-concero address call orchestratorLoan
error ConceroChildPool_CallerIsNotConcero(address caller);
///@notice error emitted when the receiver is the address(0)
error ConceroChildPool_InvalidAddress();

contract ConceroChildPool is ChildStorage, CCIPReceiver {
  using SafeERC20 for IERC20;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////

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
  ///@notice immutable variable to store the MasterPool chain selector
  uint64 private immutable i_parentPoolChainSelector;
  ///@notice immutable variable to store the MasterPool Proxy address
  address private immutable i_parentPoolProxyAddress;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a Cross-chain tx is received.
  event ConceroChildPool_CCIPReceived(bytes32 indexed ccipMessageId, uint64 srcChainSelector, address sender, address token, uint256 amount);
  ///@notice event emitted when a Cross-chain message is sent.
  event ConceroChildPool_MessageSent(bytes32 messageId, uint64 destinationChainSelector, address receiver, address linkToken, uint256 fees);
  ///@notice event emitted in OrchestratorLoan when a loan is taken
  event ConceroChildPool_LoanTaken(address receiver, uint256 amount);

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

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  receive() external payable {}

  constructor(
    address _orchestratorProxy,
    address _masterPoolProxyAddress,
    address _childProxy,
    address _link,
    address _ccipRouter,
    uint64 _destinationChainSelector,
    address _usdc,
    address _owner
  ) CCIPReceiver(_ccipRouter) ChildStorage(_owner) {
    i_infraProxy = _orchestratorProxy;
    i_childProxy = _childProxy;
    i_linkToken = LinkTokenInterface(_link);
    i_USDC = IERC20(_usdc);
    i_parentPoolChainSelector = _destinationChainSelector;
    i_parentPoolProxyAddress = _masterPoolProxyAddress;
  }

  ////////////////////////
  ///EXTERNAL FUNCTIONS///
  ////////////////////////

  /**
   * @notice Function to Distribute Liquidity across Concero Pools
   * @param _liquidityProviderAddress The liquidity provider that requested Withdraw
   * @param _amount amount of the token to be sent
   * @dev This function will sent the address of the user as data. This address will be used to update the mapping on MasterPool.
   */
  function ccipSendToPool(
    address _liquidityProviderAddress,
    uint256 _amount
  ) external onlyMessenger isProxy returns (bytes32 messageId) {
    if (_amount > i_USDC.balanceOf(address(this))) revert ConceroChildPool_InsufficientBalance();

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: address(i_USDC), amount: _amount});

    tokenAmounts[0] = tokenAmount;

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(i_parentPoolProxyAddress),
      data: abi.encode(_liquidityProviderAddress, address(0), 0), //0== lp fee. It will always be zero because here we just processing withdraws
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
      feeToken: address(i_linkToken)
    });

    uint256 fees = IRouterClient(i_ccipRouter).getFee(i_parentPoolChainSelector, evm2AnyMessage);

    if (fees > i_linkToken.balanceOf(address(this))) revert ConceroChildPool_NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

    i_USDC.approve(i_ccipRouter, _amount);
    i_linkToken.approve(i_ccipRouter, fees);

    emit ConceroChildPool_MessageSent(messageId, i_parentPoolChainSelector, i_parentPoolProxyAddress, address(i_linkToken), fees);

    messageId = IRouterClient(i_ccipRouter).ccipSend(i_parentPoolChainSelector, evm2AnyMessage);
  }

  /**
   * @notice function to the Concero Orchestrator contract take loans
   * @param _token address of the token being loaned
   * @param _amount being loaned
   * @param _receiver address of the user that will receive the amount
   * @dev only the Orchestrator contract should be able to call this function
   * @dev for ether transfer, the _receiver need to be known and trusted
   */
  function orchestratorLoan(address _token, uint256 _amount, address _receiver) external isProxy {
    if (msg.sender != i_infraProxy) revert ConceroChildPool_CallerIsNotConcero(msg.sender);
    if (_amount > IERC20(_token).balanceOf(address(this))) revert ConceroChildPool_InsufficientBalance();
    if (_receiver == address(0)) revert ConceroChildPool_InvalidAddress();

    s_loansInUse = s_loansInUse + _amount;

    IERC20(_token).safeTransfer(_receiver, _amount);

    emit ConceroChildPool_LoanTaken(_receiver, _amount);
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
    (/*address liquidityProvider*/, address _user, uint256 receivedFee) = abi.decode(any2EvmMessage.data, (address, address, uint256));

    uint256 amountMinusFees = (any2EvmMessage.destTokenAmounts[0].amount - receivedFee);

    //If receivedFee > 0, it means is user transaction. If receivedFee == 0, means it's a deposit from ParentPool
    if (receivedFee > 0) {
      IStorage.Transaction memory transaction = IStorage(i_infraProxy).getTransactionsInfo(any2EvmMessage.messageId);

      if(transaction.ccipMessageId == any2EvmMessage.messageId && transaction.isConfirmed == false || transaction.ccipMessageId == 0){
        i_USDC.safeTransfer(_user, amountMinusFees);
        //We don't subtract it here because the loan was not performed. And the value is not summed into the `s_loanInUse` variable.
      } else  {
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
}
