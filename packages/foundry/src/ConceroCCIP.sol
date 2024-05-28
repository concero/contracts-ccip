// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICCIP} from "./IConcero.sol";
import {ConceroFunctions} from "./ConceroFunctions.sol";

contract ConceroCCIP is ICCIP, ConceroFunctions {
  using SafeERC20 for IERC20;

  LinkTokenInterface private immutable i_linkToken;
  IRouterClient internal immutable i_ccipRouter;

  modifier onlyAllowListedChain(uint64 _chainSelector) {
    if (s_conceroContracts[_chainSelector] == address(0)) revert ChainNotAllowed(_chainSelector);
    _;
  }

  modifier onlyAllowlistedSenderAndChainSelector(uint64 _chainSelector, address _sender) {
    if (s_conceroContracts[_chainSelector] == address(0)) revert SourceChainNotAllowed(_chainSelector);
    if (s_conceroContracts[_chainSelector] != _sender) revert SenderNotAllowed(_sender);
    _;
  }

  //@audit we should remove it and relocate the if inside the function
  modifier validateReceiver(address _receiver) {
    if (_receiver == address(0)) revert InvalidReceiverAddress();
    _;
  }

  modifier tokenAmountSufficiency(address _token, uint256 _amount) {
    if(IERC20(_token).balanceOf(msg.sender) < _amount) revert InsufficientBalance();
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
    address _ccipRouter
  )
    ConceroFunctions(_functionsRouter, _donHostedSecretsVersion, _donId, _donHostedSecretsSlotId, _subscriptionId, _chainSelector, _chainIndex)
  {
    i_linkToken = LinkTokenInterface(_link);
    i_ccipRouter = IRouterClient(_ccipRouter);
    s_messengerContracts[msg.sender] = true;
  }

  function _sendTokenPayLink(
    uint64 _destinationChainSelector,
    address _token,
    uint256 _amount,
    uint256 _lpFee
  ) internal onlyAllowListedChain(_destinationChainSelector) returns (bytes32 messageId) {

    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage( _token, _amount, _lpFee, _destinationChainSelector);
    
    uint256 fees = i_ccipRouter.getFee(_destinationChainSelector, evm2AnyMessage);

    if (fees > i_linkToken.balanceOf(address(this))) revert NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

    i_linkToken.approve(address(i_ccipRouter), fees);
    //@audit Should we use `safeIncreaseAllowance` here?
    IERC20(_token).approve(address(i_ccipRouter), _amount);

    messageId = i_ccipRouter.ccipSend(_destinationChainSelector, evm2AnyMessage);
  }

  function _buildCCIPMessage(
    address _token,
    uint256 _amount,
    uint256 _lpFee,
    uint64 _destinationChainSelector
  ) internal view returns (Client.EVM2AnyMessage memory) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

    return
      Client.EVM2AnyMessage({
        receiver: abi.encode(s_conceroContracts[_destinationChainSelector]),
        data: abi.encode(_lpFee),
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
        feeToken: address(i_linkToken)
      });
  }
}
