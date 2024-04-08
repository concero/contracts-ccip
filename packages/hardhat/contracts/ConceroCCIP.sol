// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OwnerIsCreator} from '@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol';
import {CCIPReceiver} from '@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol';
import {IERC20} from '@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol';
import {Client} from '@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol';
import {IRouterClient} from '@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol';
import {IConcero} from "./IConcero.sol";

contract ConceroCCIP is CCIPReceiver, IConcero {
    mapping(uint64 => bool) public allowListedDstChains;
    mapping(uint64 => bool) public allowListedSrcChains;
    mapping(address => bool) public allowListedSenders;

    address immutable private s_linkToken;
    address internal externalConceroBridge;
    address internal internalFunctionContract;

    modifier onlyAllowListedDstChain(uint64 _dstChainSelector) {
        if (!allowListedDstChains[_dstChainSelector]) {
            revert DestinationChainNotAllowed(_dstChainSelector);
        }
        _;
    }

    modifier onlyAllowlistedSenderAndChainSelector(
        uint64 _sourceChainSelector,
        address _sender
    ) {
        if (!allowListedSrcChains[_sourceChainSelector])
            revert SourceChainNotAllowed(_sourceChainSelector);
        if (!allowListedSenders[_sender]) revert SenderNotAllowed(_sender);
        _;
    }

    modifier onlyFunctionContract() {
        if (msg.sender != internalFunctionContract) {
            revert NotFunctionContract(msg.sender);
        }
        _;
    }

    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) {
            revert InvalidReceiverAddress();
        }
        _;
    }

    modifier tokenAmountSufficiency(address _token, uint256 _amount) {
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            'Insufficient balance'
        );
        _;
    }

    constructor(address _link, address _ccipRouter, address _externalConceroBridge) CCIPReceiver(_ccipRouter) {
        s_linkToken = _link;
        externalConceroBridge = _externalConceroBridge;
    }

    function _sendTokenPayLink(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    )
    internal
    onlyAllowListedDstChain(_destinationChainSelector)
    validateReceiver(_receiver)
    returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _token,
            _amount,
            s_linkToken
        );

        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(s_linkToken).balance) {
            revert NotEnoughBalance(address(s_linkToken).balance, fees);
        }

        IERC20(_token).approve(address(router), _amount);

        messageId = router.ccipSend{value: fees}(
            _destinationChainSelector,
            evm2AnyMessage
        );

        emit CCIPSent(messageId, msg.sender, externalConceroBridge, _token, _amount, _destinationChainSelector);

        return messageId;
    }

    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeToken
    ) private view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
        memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
            receiver: abi.encode(externalConceroBridge),
            data: abi.encode(_receiver),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: _feeToken
        });
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
    internal
    override
    onlyAllowlistedSenderAndChainSelector(
    any2EvmMessage.sourceChainSelector,
    abi.decode(any2EvmMessage.sender, (address))
    )
    {
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
