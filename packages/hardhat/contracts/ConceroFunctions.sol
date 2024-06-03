// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IFunctions} from "./IConcero.sol";
import {Concero} from "./Concero.sol";
import {ConceroPool} from "./ConceroPool.sol";
import {ConceroCommon} from "./ConceroCommon.sol";

contract ConceroFunctions is FunctionsClient, IFunctions, ConceroCommon {
  using FunctionsRequest for FunctionsRequest.Request;

  uint32 internal constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  uint256 internal constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000;
  uint8 internal constant CL_SRC_RESPONSE_LENGTH = 96;
  string internal constant JS_CODE =
    "try { await import('npm:ethers@6.10.0'); const c = BigInt(bytesArgs[1]) === 1n ? secrets.DST_JS : secrets.SRC_JS; const h = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(c)); const r = Array.from(new Uint8Array(h)) .map(b => ('0' + b.toString(16)).slice(-2).toLowerCase()) .join(''); const b = bytesArgs[0].toLowerCase(); if ('0x' + r === b) return await eval(c); throw new Error(`0x${r} != ${b}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";

  bytes32 private immutable i_donId;
  uint64 private immutable i_subscriptionId;

  uint8 private s_donHostedSecretsSlotId;
  uint64 private s_donHostedSecretsVersion;

  bytes32 private s_srcJsHashSum;
  bytes32 private s_dstJsHashSum;

  uint256 public s_latestLinkUsdcRate;
  uint256 public s_latestNativeUsdcRate;
  uint256 public s_latestLinkNativeRate;

  mapping(bytes32 => Transaction) public s_transactions;
  mapping(bytes32 => Request) public s_requests;
  mapping(uint64 => uint256) public s_lastGasPrices; // chain selector => last gas price in wei

  modifier onlyMessenger() {
    if (!s_messengerContracts[msg.sender]) revert NotMessenger(msg.sender);
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
    JsCodeHashSum memory jsCodeHashSum
  ) FunctionsClient(_functionsRouter) ConceroCommon(_chainSelector, _chainIndex) {
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    s_donHostedSecretsVersion = _donHostedSecretsVersion;
    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;
    s_srcJsHashSum = jsCodeHashSum.src;
    s_dstJsHashSum = jsCodeHashSum.dst;
  }

  function setDonHostedSecretsVersion(uint64 _version) external payable onlyOwner {
    uint64 previousValue = s_donHostedSecretsVersion;
    s_donHostedSecretsVersion = _version;
    emit DonSecretVersionUpdated(previousValue, _version);
  }

  function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external payable onlyOwner {
    uint8 previousValue = s_donHostedSecretsSlotId;
    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;
    emit DonSlotIdUpdated(previousValue, _donHostedSecretsSlotId);
  }

  function setDstJsHashSum(bytes32 _hashSum) external payable onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;
    s_dstJsHashSum = _hashSum;
    emit DestinationJsHashSumUpdated(previousValue, _hashSum);
  }

  function setSrcJsHashSum(bytes32 _hashSum) external payable onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;
    s_srcJsHashSum = _hashSum;
    emit SourceJsHashSumUpdated(previousValue, _hashSum);
  }

  function addUnconfirmedTX(
    bytes32 ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    uint64 srcChainSelector,
    CCIPToken token,
    uint256 blockNumber
  ) external onlyMessenger {
    Transaction memory transaction = s_transactions[ccipMessageId];
    if (transaction.sender != address(0)) revert TXAlreadyExists(ccipMessageId, transaction.isConfirmed);

    s_transactions[ccipMessageId] = Transaction(ccipMessageId, sender, recipient, amount, token, srcChainSelector, false);

    bytes[] memory args = new bytes[](11);
    args[0] = abi.encodePacked(s_dstJsHashSum);
    args[1] = abi.encodePacked(RequestType.checkTxSrc);
    args[2] = abi.encodePacked(s_conceroContracts[srcChainSelector]);
    args[3] = abi.encodePacked(srcChainSelector);
    args[4] = abi.encodePacked(blockNumber);
    args[5] = abi.encodePacked(ccipMessageId);
    args[6] = abi.encodePacked(sender);
    args[7] = abi.encodePacked(recipient);
    args[8] = abi.encodePacked(uint8(token));
    args[9] = abi.encodePacked(amount);
    args[10] = abi.encodePacked(CHAIN_SELECTOR);

    bytes32 reqId = sendRequest(args, JS_CODE);

    s_requests[reqId].requestType = RequestType.checkTxSrc;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  function sendRequest(bytes[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
    req.setBytesArgs(args);
    return _sendRequest(req.encodeCBOR(), i_subscriptionId, CL_FUNCTIONS_CALLBACK_GAS_LIMIT, i_donId);
  }

  function _handleDstFunctionsResponse(Request storage request) internal {
    Transaction storage transaction = s_transactions[request.ccipMessageId];

    _confirmTX(request.ccipMessageId, transaction);

    uint256 amount = transaction.amount - getDstTotalFeeInUsdc(transaction.amount);
    address tokenReceived = getToken(transaction.token);

    //@audit hardcode for CCIP-BnM - Should be USDC
    if (tokenReceived == getToken(CCIPToken.bnm)) {
      ConceroPool conceroPool = ConceroPool(payable(s_conceroPools[CHAIN_SELECTOR]));
      conceroPool.orchestratorLoan(tokenReceived, amount, transaction.recipient);
      emit TXReleased(request.ccipMessageId, transaction.sender, transaction.recipient, tokenReceived, amount);
    } else {
      //@audit We need to call the DEX module here.
      // dexSwap.conceroEntry(passing the user address as receiver);
    }
  }

  function _handleSrcFunctionsResponse(bytes memory response) internal {
    if (response.length != CL_SRC_RESPONSE_LENGTH) {
      return;
    }

    (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector, uint256 linkUsdcRate, uint256 nativeUsdcRate, uint256 linkNativeRate) = abi.decode(
      response,
      (uint256, uint256, uint256, uint256, uint256, uint256)
    );

    s_lastGasPrices[CHAIN_SELECTOR] = srcGasPrice;
    s_lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    s_latestLinkUsdcRate = linkUsdcRate;
    s_latestNativeUsdcRate = nativeUsdcRate;
    s_latestLinkNativeRate = linkNativeRate;
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    Request storage request = s_requests[requestId];

    if (!request.isPending) {
      revert UnexpectedRequestID(requestId);
    }

    request.isPending = false;

    if (err.length > 0) {
      emit FunctionsRequestError(request.ccipMessageId, requestId, uint8(request.requestType));
      return;
    }

    if (request.requestType == RequestType.checkTxSrc) {
      _handleSrcFunctionsResponse(response);
    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      _handleDstFunctionsResponse(request);
    }
  }

  function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
    return amount / 1000;
    //@audit we can have loss of precision here?
  }

  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    if (transaction.sender == address(0)) revert TxDoesNotExist();
    if (transaction.isConfirmed == true) revert TxAlreadyConfirmed();

    transaction.isConfirmed = true;

    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }

  function sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, CCIPToken token) internal {
    if (s_conceroContracts[dstChainSelector] == address(0)) revert AddressNotSet();

    bytes[] memory args = new bytes[](11);
    args[0] = abi.encodePacked(s_srcJsHashSum);
    args[1] = abi.encodePacked(RequestType.addUnconfirmedTxDst);
    args[2] = abi.encodePacked(s_conceroContracts[dstChainSelector]);
    args[3] = abi.encodePacked(ccipMessageId);
    args[4] = abi.encodePacked(sender);
    args[5] = abi.encodePacked(recipient);
    args[6] = abi.encodePacked(amount);
    args[7] = abi.encodePacked(CHAIN_SELECTOR);
    args[8] = abi.encodePacked(dstChainSelector);
    args[9] = abi.encodePacked(uint8(token));
    args[10] = abi.encodePacked(block.number);

    bytes32 reqId = sendRequest(args, JS_CODE);
    s_requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }
}
