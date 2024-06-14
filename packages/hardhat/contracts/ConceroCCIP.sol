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
  LinkTokenInterface internal immutable i_linkToken;
  IRouterClient internal immutable i_ccipRouter;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when the Chainlink Function Fee is updated
  event CLFPremiumFeeUpdated(uint64 chainSelector, uint256 previousValue, uint256 feeAmount);

  constructor(
    FunctionsVariables memory _variables,
    uint64 _chainSelector,
    uint _chainIndex,
    address _link,
    address _ccipRouter,
    JsCodeHashSum memory jsCodeHashSum,
    bytes32 ethersHashSum,
    address _dexSwap,
    address _pool,
    address _proxy
  ) 
    ConceroFunctions(
      _variables,
      _chainSelector, 
      _chainIndex, 
      jsCodeHashSum,
      ethersHashSum,
      _dexSwap,
      _pool,
      _proxy
  ) {
    i_linkToken = LinkTokenInterface(_link);
    i_ccipRouter = IRouterClient(_ccipRouter);
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

    uint256 fees = i_ccipRouter.getFee(_destinationChainSelector, evm2AnyMessage);

    if (fees > i_linkToken.balanceOf(address(this))) revert NotEnoughLinkBalance(i_linkToken.balanceOf(address(this)), fees);

    i_linkToken.approve(address(i_ccipRouter), fees);
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
        receiver: abi.encode(s_poolReceiver[_destinationChainSelector]),
        data: abi.encode(_lpFee),
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 300_000})),
        feeToken: address(i_linkToken)
      });
  }
}
