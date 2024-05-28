// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {ICCIP} from "./IConcero.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {ConceroFunctions} from "./ConceroFunctions.sol";

contract ConceroCCIP is CCIPReceiver, ICCIP, ConceroFunctions {
  address public immutable s_linkToken;

  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (conceroContracts[_chainSelector] == address(0)) revert ChainNotAllowed(_chainSelector);
    _;
  }

  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (conceroContracts[_chainSelector] == address(0)) revert SourceChainNotAllowed(_chainSelector);
    if (conceroContracts[_chainSelector] != _sender) revert SenderNotAllowed(_sender);
    _;
  }

  modifier validateReceiver(address _receiver) {
    if (_receiver == address(0)) revert InvalidReceiverAddress();
    _;
  }

  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint8 _donHostedSecretsSlotId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex,
    address _link,
    address _ccipRouter,
    JsCodeHashSum memory jsCodeHashSum
  )
    ConceroFunctions(_functionsRouter, _donHostedSecretsVersion, _donId, _donHostedSecretsSlotId, _subscriptionId, _chainSelector, _chainIndex, jsCodeHashSum)
    CCIPReceiver(_ccipRouter)
  {
    s_linkToken = _link;
    messengerContracts[msg.sender] = true;
  }

  function _sendTokenPayLink(
    uint64 _destinationChainSelector,
    address _receiver,
    address _token,
    uint256 _amount
  ) internal onlyAllowListedChain(_destinationChainSelector) validateReceiver(_receiver) returns (bytes32 messageId) {
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _token, _amount, s_linkToken, _destinationChainSelector);
    IRouterClient router = IRouterClient(this.getRouter());
    uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);
    if (fees > IERC20(s_linkToken).balanceOf(address(this))) {
      revert NotEnoughBalance(IERC20(s_linkToken).balanceOf(address(this)), fees);
    }
    IERC20(s_linkToken).approve(address(router), fees);
    IERC20(_token).approve(address(router), _amount);
    messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);
    return messageId;
  }

  function _buildCCIPMessage(
    address _receiver,
    address _token,
    uint256 _amount,
    address _feeToken,
    uint64 _destinationChainSelector
  ) internal view returns (Client.EVM2AnyMessage memory) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

    return
      Client.EVM2AnyMessage({
        receiver: abi.encode(conceroContracts[_destinationChainSelector]),
        data: abi.encode(_receiver),
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
        feeToken: _feeToken
      });
  }

  function _ccipReceive(
    Client.Any2EVMMessage memory any2EvmMessage
  ) internal override onlyAllowlistedSenderAndChainSelector(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) {
    emit CCIPReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector,
      abi.decode(any2EvmMessage.sender, (address)),
      abi.decode(any2EvmMessage.data, (address)),
      any2EvmMessage.destTokenAmounts[0].token,
      any2EvmMessage.destTokenAmounts[0].amount
    );
  }
}
