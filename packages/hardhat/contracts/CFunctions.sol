// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from '@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol';
import {ConfirmedOwner} from '@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol';
import {FunctionsRequest} from '@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract CFunctions is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    struct Transaction {
        bytes32 ccipMessageId;
        address sender;
        address recipient;
        uint256 amount;
        address token;
        uint64 srcChainSelector;
        bool isConfirmed;
    }

    bytes32 private donId;
    bytes32 private lastRequestId;
    uint8 private donHostedSecretsSlotID;
    uint64 private donHostedSecretsVersion;

    string immutable jsCode = "const ethers = await import('npm:ethers@6.10.0');const [srcContractAddress, messageId] = args;const params = { url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`, method: 'POST', headers: {  'Content-Type': 'application/json', }, data: {  jsonrpc: '2.0',  method: 'eth_getLogs',  id: 1,  params: [   {    address: srcContractAddress,    topics: [null, messageId],    fromBlock: 'earliest',    toBlock: 'latest',   },  ], },};const response = await Functions.makeHttpRequest(params);const { data } = response;if (data?.error || !data?.result) { throw new Error('Error fetching logs');}const abi = ['event CCIPSent(bytes32 indexed, address, address, address, uint256, uint64)'];const contract = new ethers.Interface(abi);const log = { topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]], data: data.result[0].data,};const decodedLog = contract.parseLog(log);const croppedArgs = args.slice(1);for (let i = 0; i < decodedLog.args.length; i++) { if (decodedLog.args[i].toString() !== croppedArgs[i].toString()) {  throw new Error('Message ID does not match the event log'); }}return Functions.encodeString(messageId);";

    mapping(address => bool) private allowlist;
    mapping(bytes32 => Transaction) public transactions;

    // Events
    event UnconfirmedTXAdded(
        bytes32 indexed ccipMessageId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        address token
    );
    event TXConfirmed(
        bytes32 indexed ccipMessageId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        address token
    );
    event TXReleased(bytes32 indexed ccipMessageId, address indexed recipient, uint256 amount, address token);
    event AllowlistUpdated(address indexed walletAddress, bool status);

    // Errors
    error NotAllowed();
    error TXAlreadyExists(bytes32 txHash, bool isConfirmed);
    error UnexpectedRequestID(bytes32);

    modifier onlyAllowListedSenders() {
        if (!allowlist[msg.sender]) revert NotAllowed();
        _;
    }

    constructor(address _router, bytes32 _donId) FunctionsClient(_router) ConfirmedOwner(msg.sender) {
        donId = _donId;
        allowlist[msg.sender] = true; // add owner to allowlist
    }

    function addToAllowlist(address _walletAddress) external onlyOwner {
        require(_walletAddress != address(0), 'Invalid address');
        require(!allowlist[_walletAddress], 'Address already in allowlist');
        allowlist[_walletAddress] = true;
        emit AllowlistUpdated(_walletAddress, true);
    }

    function removeFromAllowlist(address _walletAddress) external onlyOwner {
        require(_walletAddress != address(0), 'Invalid address');
        require(allowlist[_walletAddress], 'Address not in allowlist');
        allowlist[_walletAddress] = false;
        emit AllowlistUpdated(_walletAddress, true);
    }

    function addUnconfirmedTX(
        bytes32 ccipMessageId,
        address sender,
        address recipient,
        uint256 amount,
        uint64 srcChainSelector,
        address token
    ) external onlyAllowListedSenders {
        Transaction storage transaction = transactions[ccipMessageId];
        if (transaction.sender != address(0)) revert TXAlreadyExists(ccipMessageId, transaction.isConfirmed);
        transactions[ccipMessageId] = Transaction(
            ccipMessageId,
            sender,
            recipient,
            amount,
            token,
            srcChainSelector,
            false
        );
        emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token);

        sendRequest(
            [
            toHexString(ccipMessageId),
            toHexString(sender),
            toHexString(recipient),
            toHexString(token),
            toString(amount),
            toString(srcChainSelector)
            ]
        );
    }

    function sendRequest(string[] calldata args) internal {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(jsCode);
        req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
        req.setArgs(args);
        lastRequestId = _sendRequest(req.encodeCBOR(), 0, 300_000, donId);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }

        if (err.length > 0) {
            revert(string(err));
        }

        _confirmTX(toEthSignedMessageHash(response));
    }

    function _confirmTX(bytes32 ccipMessageId) internal {
        Transaction storage transaction = transactions[ccipMessageId];
        require(transaction.sender != address(0), 'TX does not exist');
        require(!transaction.isConfirmed, 'TX already confirmed');
        transaction.isConfirmed = true; // Confirm the transaction

        emit TXConfirmed(
            ccipMessageId,
            transaction.sender,
            transaction.recipient,
            transaction.amount,
            transaction.token
        );

        //todo Releases the TX to the recipient
        emit TXReleased(ccipMessageId, transaction.recipient, transaction.amount, transaction.token);
    }

    receive() external payable {}

    fallback() external payable {}
}
