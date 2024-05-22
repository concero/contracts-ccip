// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IFunctions} from "./IConcero.sol";
import {Concero} from "./Concero.sol";
import {ConceroCommon} from "./ConceroCommon.sol";

contract ConceroFunctions is FunctionsClient, IFunctions, ConceroCommon {
  using FunctionsRequest for FunctionsRequest.Request;
  using Strings for uint256;
  using Strings for uint64;
  using Strings for address;
  using Strings for bytes32;

  struct JsCodeHashSum {
    bytes32 src;
    bytes32 dst;
  }

  uint32 public immutable CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  uint256 public immutable CL_FUNCTIONS_GAS_OVERHEAD = 185_000;
  bytes32 private immutable donId;
  uint64 private immutable subscriptionId;

  uint8 private donHostedSecretsSlotId;
  uint64 private donHostedSecretsVersion;

  bytes32 private srcJsHashSum;
  bytes32 private dstJsHashSum;

  mapping(bytes32 => Transaction) public transactions;
  mapping(bytes32 => Request) public requests;
  mapping(uint64 => uint256) public lastGasPrices; // chain selector => last gas price in wei

  string private constant srcJsCode =
    "try { await import('npm:ethers@6.10.0'); const crypto = await import('node:crypto'); const hash = crypto.createHash('sha256').update(secrets.SRC_JS, 'utf8').digest('hex'); if (hash.toLowerCase() === args[0].toLowerCase()) return await eval(secrets.SRC_JS); throw new Error('Invalid hash'); } catch (err) { throw new Error(err.message.slice(0, 255));}";
  string private constant dstJsCode =
    "try { await import('npm:ethers@6.10.0'); const crypto = await import('node:crypto'); const hash = crypto.createHash('sha256').update(secrets.DST_JS, 'utf8').digest('hex'); if (hash.toLowerCase() === args[0].toLowerCase()) return await eval(secrets.DST_JS); throw new Error('Invalid hash'); } catch (err) { throw new Error(err.message.slice(0, 255));}";

  modifier onlyMessenger() {
    if (!messengerContracts[msg.sender]) revert NotMessenger(msg.sender);
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
    donId = _donId;
    subscriptionId = _subscriptionId;
    donHostedSecretsVersion = _donHostedSecretsVersion;
    donHostedSecretsSlotId = _donHostedSecretsSlotId;
    srcJsHashSum = jsCodeHashSum.src;
    dstJsHashSum = jsCodeHashSum.dst;
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    donHostedSecretsVersion = _version;
  }

  function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external onlyOwner {
    donHostedSecretsSlotId = _donHostedSecretsSlotId;
  }

  function setDstJsHashSum(bytes32 hashSum) external onlyOwner {
    dstJsHashSum = hashSum;
  }

  function setSrcJsHashSum(bytes32 hashSum) external onlyOwner {
    srcJsHashSum = hashSum;
  }

  function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
    bytes32 out;
    for (uint i = 0; i < 32; i++) {
      out |= bytes32(b[i] & 0xFF) >> (i * 8);
    }
    return out;
  }

  function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
    bytes memory chars = "0123456789abcdef";
    bytes memory str = new bytes(64);
    for (uint256 i = 0; i < 32; i++) {
      bytes1 b = _bytes32[i];
      str[i * 2] = chars[uint8(b) >> 4];
      str[i * 2 + 1] = chars[uint8(b) & 0x0f];
    }
    return string(abi.encodePacked("0x", str));
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
    Transaction storage transaction = transactions[ccipMessageId];
    if (transaction.sender != address(0)) revert TXAlreadyExists(ccipMessageId, transaction.isConfirmed);
    transactions[ccipMessageId] = Transaction(ccipMessageId, sender, recipient, amount, token, srcChainSelector, false);

    string[] memory args = new string[](9);
    //todo: use bytes
    args[0] = bytes32ToString(srcJsHashSum);
    args[1] = Strings.toHexString(conceroContracts[srcChainSelector]);
    args[2] = Strings.toString(srcChainSelector);
    args[3] = Strings.toHexString(blockNumber);
    args[4] = bytes32ToString(ccipMessageId);
    args[5] = Strings.toHexString(sender);
    args[6] = Strings.toHexString(recipient);
    args[7] = Strings.toString(uint(token));
    args[8] = Strings.toString(amount);
    args[9] = Strings.toString(chainSelector);

    bytes32 reqId = sendRequest(args, dstJsCode);
    requests[reqId].requestType = RequestType.checkTxSrc;
    requests[reqId].isPending = true;
    requests[reqId].ccipMessageId = ccipMessageId;
    emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  function sendRequest(string[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(donHostedSecretsSlotId, donHostedSecretsVersion);
    req.setArgs(args);
    return _sendRequest(req.encodeCBOR(), subscriptionId, CL_FUNCTIONS_CALLBACK_GAS_LIMIT, donId);
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    Request storage request = requests[requestId];

    if (!request.isPending) {
      revert UnexpectedRequestID(requestId);
    }

    request.isPending = false;
    if (err.length > 0) {
      emit FunctionsRequestError(request.ccipMessageId, requestId, uint8(request.requestType));
      return;
    }

    if (request.requestType == RequestType.checkTxSrc) {
      Transaction storage transaction = transactions[request.ccipMessageId];
      _confirmTX(request.ccipMessageId, transaction);
      uint256 amount = transaction.amount - getDstTotalFeeInUsdc(transaction.amount);
      sendTokenToEoa(request.ccipMessageId, transaction.sender, transaction.recipient, getToken(transaction.token), amount);
    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      if (response.length != 96) {
        return;
      }

      (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector) = abi.decode(response, (uint256, uint256, uint256));
      lastGasPrices[chainSelector] = srcGasPrice;
      lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    }
  }

  function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
    return amount / 1000;
  }

  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    require(transaction.sender != address(0), "TX does not exist");
    require(!transaction.isConfirmed, "TX already confirmed");
    transaction.isConfirmed = true;
    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }

  function sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, CCIPToken token) internal {
    if (conceroContracts[dstChainSelector] == address(0)) revert("address not set");

    string[] memory args = new string[](9);
    //todo: Strings usage may not be required here. Consider ways of passing data without converting to string
    args[0] = bytes32ToString(dstJsHashSum);
    args[1] = Strings.toHexString(conceroContracts[dstChainSelector]);
    args[2] = bytes32ToString(ccipMessageId);
    args[3] = Strings.toHexString(sender);
    args[4] = Strings.toHexString(recipient);
    args[5] = Strings.toString(amount);
    args[6] = Strings.toString(chainSelector);
    args[7] = Strings.toString(dstChainSelector);
    args[8] = Strings.toString(uint(token));
    args[9] = Strings.toHexString(block.number);

    bytes32 reqId = sendRequest(args, srcJsCode);
    requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    requests[reqId].isPending = true;
    requests[reqId].ccipMessageId = ccipMessageId;
    emit UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }

  function sendTokenToEoa(bytes32 _ccipMessageId, address _sender, address _recipient, address _token, uint256 _amount) internal {
    bool isOk = IERC20(_token).transfer(_recipient, _amount);
    if (isOk) {
      emit TXReleased(_ccipMessageId, _sender, _recipient, _token, _amount);
    } else {
      emit TXReleaseFailed(_ccipMessageId, _sender, _recipient, _token, _amount);
      revert SendTokenFailed(_ccipMessageId, _token, _amount, _recipient);
    }
  }
}
