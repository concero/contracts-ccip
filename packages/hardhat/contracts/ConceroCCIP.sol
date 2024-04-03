// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.19;

import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {ConceroFunctionsConsumer} from "contracts/ConceroFunctionsConsumer.sol";

contract ConceroCCIP is CCIPReceiver, ConceroFunctionsConsumer {
    mapping(uint64 => bool) public allowListedDstChains;
    mapping(uint64 => bool) public allowListedSrcChains;
    mapping(address => bool) public allowListedSenders;

    address private s_linkToken;

    error DestinationChainNotAllowed(uint64 _dstChainSelector);
    error InvalidReceiverAddress();
    error NotEnoughBalance(uint256 _fees, uint256 _feeToken);
    error SourceChainNotAllowed(uint64 _sourceChainSelector);
    error SenderNotAllowed(address _sender);
    error NothingToWithdraw();
    error FailedToWithdrawEth(address owner, address target, uint256 value);

    event CCIPSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    event CCIPReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        string data,
        address token,
        uint256 tokenAmount
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

    modifier tokenAmountSufficiency(address _token, uint256 _amount) {
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            "Insufficient balance"
        );
        _;
    }

    constructor(
        address _link,
        address _ccipRouter,
        address _functionsRouter,
        bytes32 _donId
    )
    CCIPReceiver(_ccipRouter)
    ConceroFunctionsConsumer(_functionsRouter, _donId)
    {
        s_linkToken = _link;
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

    function startTransaction(
        address _token,
        uint256 _amount,
        uint64 _destinationChainSelector,
        address _receiver
    ) external payable tokenAmountSufficiency(_token, _amount) {
        bool isOK = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        require(isOK, "Transfer failed");

        _sendTokenPayLink(
            _destinationChainSelector,
            _receiver,
            _token,
            _amount
        );
    }

    function _sendTokenPayLink(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    ) private
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

        emit CCIPSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            s_linkToken,
            fees
        );

        // sendRequest()

        return messageId;
    }

    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeToken
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
        memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encode(""),
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
        emit CCIPReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            abi.decode(any2EvmMessage.data, (string)),
            any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts[0].amount
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
