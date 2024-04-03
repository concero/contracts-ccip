// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CCIPFacet is CCIPReceiver, OwnerIsCreator {
    mapping(uint64 => bool) public allowListedDstChains;
    mapping(uint64 => bool) public allowListedSrcChains;
    mapping(address => bool) public allowListedSenders;

    IERC20 private s_linkToken;

    error DestinationChainNotAllowed(uint64 _dstChainSelector);
    error InvalidReceiverAddress();
    error NotEnoughBalance(uint256 _fees, uint256 _feeToken);
    error SourceChainNotAllowed(uint64 _sourceChainSelector);
    error SenderNotAllowed(address _sender);
    error NothingToWithdraw();
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    bytes32 private s_lastReceivedMessageId;
    address private s_lastReceivedTokenAddress;
    uint256 private s_lastReceivedTokenAmount;
    string private s_lastReceivedText;

    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        string text, // The text being sent.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        string text, // The text that was received.
        address token, // The token address that was transferred.
        uint256 tokenAmount // The token amount that was transferred.
    );

    modifier onlyAllowListedDstChain(uint64 _dstChainSelector) {
        if (!allowListedDstChains[_dstChainSelector]) {
            revert DestinationChainNotAllowed(_dstChainSelector);
        }
        _;
    }

    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) {
            revert InvalidReceiverAddress();
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

    constructor(address _link, address _router) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
    }

    function allowDestinationChain(uint64 _dstChainSelector, bool allowed)
    external
    onlyOwner
    {
        allowListedDstChains[_dstChainSelector] = allowed;
    }

    function allowSourceChain(uint64 _srcChainSelector, bool allowed)
    external
    onlyOwner
    {
        allowListedSrcChains[_srcChainSelector] = allowed;
    }

    function allowListSender(address _sender, bool allowed) external onlyOwner {
        allowListedSenders[_sender] = allowed;
    }

    function sendMessageAndPayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount
    )
    external
    onlyOwner
    onlyAllowListedDstChain(_destinationChainSelector)
    validateReceiver(_receiver)
    returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            _token,
            _amount,
            address(s_linkToken)
        );

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);
        }

        // should we check if approve needed?
        s_linkToken.approve(address(router), fees);
        IERC20(_token).approve(address(router), _amount);

        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            _token,
            _amount,
            address(s_linkToken),
            fees
        );

        return messageId;
    }

    function sendMessagePayNative(
        uint64 _destinationChainSelector,
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount
    )
    external
    onlyOwner
    onlyAllowListedDstChain(_destinationChainSelector)
    validateReceiver(_receiver)
    returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            _token,
            _amount,
            address(0)
        );

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        IERC20(_token).approve(address(router), _amount);

        messageId = router.ccipSend{value: fees}(
            _destinationChainSelector,
            evm2AnyMessage
        );

        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _text,
            _token,
            _amount,
            address(0),
            fees
        );

        return messageId;
    }

    function _buildCCIPMessage(
        address _receiver,
        string calldata _text,
        address _token,
        uint256 _amount,
        address _feeToken
    ) private pure returns (Client.EVM2AnyMessage memory) {
        // we can send multiple tokens in one transaction
        Client.EVMTokenAmount[]
        memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encode(_text),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: _feeToken
        });
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage)
    internal
    override
    onlyAllowlistedSenderAndChainSelector(
    any2EvmMessage.sourceChainSelector,
    abi.decode(any2EvmMessage.sender, (address))
    )
    {
        s_lastReceivedMessageId = any2EvmMessage.messageId;
        s_lastReceivedText = abi.decode(any2EvmMessage.data, (string));
        s_lastReceivedTokenAddress = any2EvmMessage.destTokenAmounts[0].token;
        s_lastReceivedTokenAmount = any2EvmMessage.destTokenAmounts[0].amount;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            abi.decode(any2EvmMessage.data, (string)),
            any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts[0].amount
        );
    }

    function getLastReceivedMessageDetails()
    public
    view
    returns (
        bytes32 messageId,
        string memory text,
        address tokenAddress,
        uint256 tokenAmount
    )
    {
        return (
            s_lastReceivedMessageId,
            s_lastReceivedText,
            s_lastReceivedTokenAddress,
            s_lastReceivedTokenAmount
        );
    }

    receive() external payable {}

    function withdraw(address _owner) public onlyOwner {
        uint256 amount = address(this).balance;

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        (bool sent,) = _owner.call{value: amount}("");

        if (!sent) {
            revert FailedToWithdrawEth(msg.sender, _owner, amount);
        }
    }

    function withdrawToken(address _owner, address _token) public onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        IERC20(_token).transfer(_owner, amount);
    }
}
