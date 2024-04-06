// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import {FunctionsClient} from '@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol';
import {ConfirmedOwner} from '@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol';
import {FunctionsRequest} from '@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol';

contract CFunctions is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    struct Transaction {
        address sender;
        address recipient;
        uint256 amount;
        address token;
        uint64 srcChainSelector;
        bool isConfirmed;
    }

    bytes32 private donId;
    bytes32 private lastRequestId;
    mapping(address => bool) private allowlist;
    mapping(bytes32 => Transaction) public transactions;
    bytes32[] public transactionHashes;

    // Events
    event UnconfirmedTXAdded(bytes32 indexed txHash, address indexed sender, address indexed recipient, uint256 amount, address token);
    event TXConfirmed(bytes32 indexed txHash, address indexed sender, address indexed recipient, uint256 amount, address token);
    event TXReleased(bytes32 indexed txHash, address indexed recipient, uint256 amount, address token);
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
    }

    function addToAllowlist(address _walletAddress) external onlyOwner {
        allowlist[_walletAddress] = true;
        emit AllowlistUpdated(_walletAddress, true);
    }

    function removeFromAllowlist(address _walletAddress) external onlyOwner {
        allowlist[_walletAddress] = false;
        emit AllowlistUpdated(_walletAddress, true);
    }

    function addUnconfirmedTX(bytes32 txHash, address sender, address recipient, uint256 amount, uint64 srcChainSelector, address token) external onlyAllowListedSenders {
        Transaction storage transaction = transactions[txHash];
        if (transaction.sender != address(0)) revert TXAlreadyExists(txHash, transaction.isConfirmed);
        transactions[txHash] = Transaction(sender, recipient, amount, token, srcChainSelector, false);
        emit UnconfirmedTXAdded(txHash, sender, recipient, amount, token);
        //TODO Triggers CL Functions to check if TX present on SRC
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }
        //        string memory response = string(response);
        //TODO get txHash from fulfill, then call _confirmTX(txHash)
        //        _confirmTX(txHash);
    }

    function _confirmTX(bytes32 txHash) internal {
        Transaction storage transaction = transactions[txHash];
        require(transaction.sender != address(0), 'TX does not exist');
        require(!transaction.isConfirmed, 'TX already confirmed');
        transaction.isConfirmed = true; // Confirm the transaction

        emit TXConfirmed(txHash, transaction.sender, transaction.recipient, transaction.amount, transaction.token);

        //todo Releases the TX to the recipient
        emit TXReleased(txHash, transaction.recipient, transaction.amount, transaction.token);
    }
}
