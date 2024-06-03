// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ConceroFunctions} from "./ConceroFunctions.sol";

  ////////////////////////////////////////////////////////
  //////////////////////// ERRORS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice error emitted when the destination chain is not allowed
  error ChainNotAllowed(uint64 ChainSelector);
  ///@notice error emitted when the source chain is not allowed
  error SourceChainNotAllowed(uint64 sourceChainSelector);
  ///@notice error emitted when the sender of the message is not allowed
  error SenderNotAllowed(address sender);
  ///@notice error emitted when the receiver address is invalid
  error InvalidReceiverAddress();
  ///@notice error emitted when the link balance is not enough to send the message
  error NotEnoughLinkBalance(uint256 fees, uint256 feeToken);

contract ConceroCCIP is ConceroFunctions {
  using SafeERC20 for IERC20;

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  
  ////////////////
  ///IMMUTABLES///
  ////////////////
  LinkTokenInterface internal immutable LINK_TOKEN;
  IRouterClient internal immutable CCIP_ROUTER;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a CCIP message is sent
  event CCIPSent(
    bytes32 indexed ccipMessageId,
    address sender,
    address recipient,
    CCIPToken token,
    uint256 amount,
    uint64 dstChainSelector
  );
  ///@notice event emitted when the Chainlink Function Fee is updated
  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);

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
  ) ConceroFunctions(_functionsRouter, _donHostedSecretsVersion, _donId, _donHostedSecretsSlotId, _subscriptionId, _chainSelector, _chainIndex, jsCodeHashSum) {
    LINK_TOKEN = LinkTokenInterface(_link);
    CCIP_ROUTER = IRouterClient(_ccipRouter);
    s_messengerContracts[msg.sender] = APPROVED;
  }

  ///////////////////////////////////////////////////////////////
  ///////////////////////////Functions///////////////////////////
  ///////////////////////////////////////////////////////////////

  function _sendTokenPayLink(
    uint64 _destinationChainSelector,
    address _token,
    uint256 _amount,
    uint256 _lpFee
  ) internal onlyAllowListedChain(_destinationChainSelector) returns (bytes32 messageId) {
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_token, _amount, _lpFee, _destinationChainSelector);

    uint256 fees = CCIP_ROUTER.getFee(_destinationChainSelector, evm2AnyMessage);

    if (fees > LINK_TOKEN.balanceOf(address(this))) revert NotEnoughLinkBalance(LINK_TOKEN.balanceOf(address(this)), fees);

    LINK_TOKEN.approve(address(CCIP_ROUTER), fees);
    IERC20(_token).approve(address(CCIP_ROUTER), _amount);

    messageId = CCIP_ROUTER.ccipSend(_destinationChainSelector, evm2AnyMessage);
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
        receiver: abi.encode(s_poolReceiver[_destinationChainSelector]),
        data: abi.encode(_lpFee),
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
        feeToken: address(LINK_TOKEN)
      });
  }
}
