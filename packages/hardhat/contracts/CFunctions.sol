// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from '@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol';
import {ConfirmedOwner} from '@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol';
import {FunctionsRequest} from '@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract CFunctions is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;
    using Strings for uint64;
    using Strings for address;
    using Strings for bytes32;

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

    string private jsCode = "const ethers = await import('npm:ethers@6.10.0');const [srcContractAddress, messageId] = args;const params = { url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`, method: 'POST', headers: {  'Content-Type': 'application/json', }, data: {  jsonrpc: '2.0',  method: 'eth_getLogs',  id: 1,  params: [   {    address: srcContractAddress,    topics: [null, messageId],    fromBlock: 'earliest',    toBlock: 'latest',   },  ], },};const response = await Functions.makeHttpRequest(params);const { data } = response;if (data?.error || !data?.result) { throw new Error('Error fetching logs');}const abi = ['event CCIPSent(bytes32 indexed, address, address, address, uint256, uint64)'];const contract = new ethers.Interface(abi);const log = { topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]], data: data.result[0].data,};const decodedLog = contract.parseLog(log);const croppedArgs = args.slice(1);for (let i = 0; i < decodedLog.args.length; i++) { if (decodedLog.args[i].toString() !== croppedArgs[i].toString()) {  throw new Error('Message ID does not match the event log'); }}return Functions.encodeString(messageId);";

    mapping(address => bool) private allowlist;
    mapping(bytes32 => Transaction) public transactions;

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

    error NotAllowed();
    error TXAlreadyExists(bytes32 txHash, bool isConfirmed);
    error UnexpectedRequestID(bytes32);

    modifier onlyAllowListedSenders() {
        if (!allowlist[msg.sender]) revert NotAllowed();
        _;
    }

    constructor(address _router, bytes32 _donId) FunctionsClient(_router) ConfirmedOwner(msg.sender) {
        donId = _donId;
        allowlist[msg.sender] = true;
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

    function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
        donHostedSecretsVersion = _version;
    }

    function bytes32ToAddress(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }

    function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
        bytes32 out;
        uint offset = 2;

        for (uint i = 0; i < 32; i++) {
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
        }
        return out;
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

        string[] memory args = new string[](6);
        args[0] = Strings.toHexString(bytes32ToAddress(ccipMessageId));
        args[1] = Strings.toHexString(sender);
        args[2] = Strings.toHexString(recipient);
        args[3] = Strings.toHexString(token);
        args[4] = Strings.toString(amount);
        args[5] = Strings.toString(srcChainSelector);

        sendRequest(args);
    }

    function sendRequest(string[] memory args) internal {
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

        _confirmTX(bytesToBytes32(response));
    }

    function _confirmTX(bytes32 ccipMessageId) internal {
        Transaction storage transaction = transactions[ccipMessageId];
        require(transaction.sender != address(0), 'TX does not exist');
        require(!transaction.isConfirmed, 'TX already confirmed');
        transaction.isConfirmed = true;

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
}
