// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConceroCCIP} from "./ConceroCCIP.sol";
import {IFunctions} from "./IConcero.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CFunctions is FunctionsClient, ConfirmedOwner, IFunctions {
  using FunctionsRequest for FunctionsRequest.Request;
  using Strings for uint256;
  using Strings for uint64;
  using Strings for address;
  using Strings for bytes32;

  ConceroCCIP private conceroCCIP;
  bytes32 private immutable donId;
  uint8 private donHostedSecretsSlotID;
  uint64 private donHostedSecretsVersion;
  uint64 private immutable subscriptionId;
  address private externalCcipContract;
  address private externalFunctionsContract;
  address private internalCcipContract;
  uint64 private immutable chainSelector;

  mapping(address => bool) private allowlist;
  mapping(bytes32 => Transaction) public transactions;
  mapping(bytes32 => Request) public requests;

  string private constant srcJsCode =
    "const { createWalletClient, custom } = await import('npm:viem'); const { privateKeyToAccount } = await import('npm:viem/accounts'); const { polygonMumbai, avalancheFuji } = await import('npm:viem/chains'); const [contractAddress, ccipMessageId, sender, recipient, amount, srcChainSelector, dstChainSelector, token] = args; const chainSelectors = {  '12532609583862916517': {   url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`,   chain: polygonMumbai,  },  '14767482510784806043': {   url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,   chain: avalancheFuji,  }, }; const abi = [  {   name: 'addUnconfirmedTX',   type: 'function',   inputs: [    { type: 'bytes32', name: 'ccipMessageId' },    { type: 'address', name: 'sender' },    { type: 'address', name: 'recipient' },    { type: 'uint256', name: 'amount' },    { type: 'uint64', name: 'srcChainSelector' },    { type: 'address', name: 'token' },   ],   outputs: [],  }, ]; try {  const account = privateKeyToAccount('0x' + secrets.WALLET_PRIVATE_KEY);  const walletClient = createWalletClient({   account,   chain: chainSelectors[dstChainSelector].chain,   transport: custom({    async request({ method, params }) {     if (method === 'eth_chainId') return chainSelectors[dstChainSelector].chain.id;     if (method === 'eth_estimateGas') return '0x3d090';     if (method === 'eth_maxPriorityFeePerGas') return '0x3b9aca00';     const response = await Functions.makeHttpRequest({      url: chainSelectors[dstChainSelector].url,      method: 'post',      headers: { 'Content-Type': 'application/json' },      data: { jsonrpc: '2.0', id: 1, method, params },     });     return response.data.result;    },   }),  });  const hash = await walletClient.writeContract({   abi,   functionName: 'addUnconfirmedTX',   address: contractAddress,   args: [ccipMessageId, sender, recipient, amount, BigInt(srcChainSelector), token],   gas: 1000000n,  });  return Functions.encodeString(hash); } catch (err) {  return Functions.encodeString('error'); }";
  string private constant dstJsCode =
    "const ethers = await import('npm:ethers@6.10.0'); const [srcContractAddress, messageId] = args; const params = {  url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`,  method: 'POST',  headers: {   'Content-Type': 'application/json',  },  data: {   jsonrpc: '2.0',   method: 'eth_getLogs',   id: 1,   params: [    {     address: srcContractAddress,     topics: [null, messageId],     fromBlock: 'earliest',     toBlock: 'latest',    },   ],  }, }; const response = await Functions.makeHttpRequest(params); const { data } = response; if (data?.error || !data?.result) {  throw new Error('Error fetching logs'); } const abi = ['event CCIPSent(bytes32 indexed, address, address, address, uint256, uint64)']; const contract = new ethers.Interface(abi); const log = {  topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]],  data: data.result[0].data, }; const decodedLog = contract.parseLog(log); const croppedArgs = args.slice(1); for (let i = 0; i < decodedLog.args.length; i++) {  if (decodedLog.args[i].toString().toLowerCase() !== croppedArgs[i].toString().toLowerCase()) {   throw new Error('Message ID does not match the event log');  } } return Functions.encodeUint256(BigInt(messageId));";

  modifier onlyAllowListedSenders() {
    if (!allowlist[msg.sender]) revert NotAllowed();
    _;
  }

  modifier onlyInternalCCIPContract() {
    if (msg.sender != internalCcipContract) {
      revert NotCCIPContract(msg.sender);
    }
    _;
  }

  constructor(
    address _router,
    bytes32 _donId,
    uint64 _subscriptionId,
    uint64 _donHostedSecretsVersion,
    uint64 _chainSelector
  ) FunctionsClient(_router) ConfirmedOwner(msg.sender) {
    donId = _donId;
    subscriptionId = _subscriptionId;
    donHostedSecretsVersion = _donHostedSecretsVersion;
    allowlist[msg.sender] = true;
    chainSelector = _chainSelector;
  }

  function addToAllowlist(address _walletAddress) external onlyOwner {
    require(_walletAddress != address(0), "Invalid address");
    require(!allowlist[_walletAddress], "Address already in allowlist");
    allowlist[_walletAddress] = true;
    emit AllowlistUpdated(_walletAddress, true);
  }

  function removeFromAllowlist(address _walletAddress) external onlyOwner {
    require(_walletAddress != address(0), "Invalid address");
    require(allowlist[_walletAddress], "Address not in allowlist");
    allowlist[_walletAddress] = false;
    emit AllowlistUpdated(_walletAddress, true);
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    donHostedSecretsVersion = _version;
  }

  function setInternalCcipContract(address payable _internalCcipContract) external onlyOwner {
    internalCcipContract = _internalCcipContract;
    conceroCCIP = ConceroCCIP(_internalCcipContract);
  }

  function setExternalCcipContract(address _externalCcipContract) external onlyOwner {
    externalCcipContract = _externalCcipContract;
  }

  function setExternalFunctionsContract(address _externalFunctionsContract) external onlyOwner {
    externalFunctionsContract = _externalFunctionsContract;
  }

  // DELETE IN PRODUCTION! TESTING ONLY
  function deleteTransaction(bytes32 ccipMessageId) external onlyOwner {
    delete transactions[ccipMessageId];
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
    address token
  ) external onlyAllowListedSenders {
    Transaction storage transaction = transactions[ccipMessageId];
    if (transaction.sender != address(0)) revert TXAlreadyExists(ccipMessageId, transaction.isConfirmed);
    transactions[ccipMessageId] = Transaction(ccipMessageId, sender, recipient, amount, token, srcChainSelector, false);

    string[] memory args = new string[](8);
    args[0] = Strings.toHexString(externalCcipContract);
    args[1] = bytes32ToString(ccipMessageId);
    args[2] = Strings.toHexString(sender);
    args[3] = Strings.toHexString(recipient);
    args[4] = Strings.toHexString(token);
    args[5] = Strings.toString(amount);
    args[6] = Strings.toString(chainSelector);
    args[7] = Strings.toString(srcChainSelector);

    bytes32 reqId = sendRequest(args, dstJsCode);

    requests[reqId].requestType = RequestType.checkTxSrc;
    requests[reqId].isPending = true;

    emit UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  function sendRequest(string[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
    req.setArgs(args);
    return _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    if (!requests[requestId].isPending) {
      revert UnexpectedRequestID(requestId);
    }

    requests[requestId].isPending = false;

    if (requests[requestId].requestType == RequestType.checkTxSrc) {
      // TODO: handle error
      if (err.length > 0) {
        return;
      }
      _confirmTX(bytesToBytes32(response));
    }
  }

  function _confirmTX(bytes32 ccipMessageId) internal {
    Transaction storage transaction = transactions[ccipMessageId];
    address tokenToSend;
    require(transaction.sender != address(0), "TX does not exist");
    require(!transaction.isConfirmed, "TX already confirmed");
    transaction.isConfirmed = true;

    emit TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);

    if (address(conceroCCIP) == address(0)) {
      revert("conceroCCIP address not set");
    }

    //todo use mapping later and maybe move/add to CLF
    if (transaction.token == 0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40) {
      tokenToSend = 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4;
    } else if (transaction.token == 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4) {
      tokenToSend = 0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40;
    }

    conceroCCIP.sendTokenToEoa(ccipMessageId, transaction.sender, transaction.recipient, tokenToSend, transaction.amount);
  }

  function sendUnconfirmedTX(
    bytes32 ccipMessageId,
    address sender,
    address recipient,
    uint256 amount,
    uint64 dstChainSelector,
    address token
  ) external onlyInternalCCIPContract {
    if (externalFunctionsContract == address(0)) {
      revert("externalFunctionsContract address not set");
    }

    string[] memory args = new string[](8);
    args[0] = Strings.toHexString(externalFunctionsContract);
    args[1] = bytes32ToString(ccipMessageId);
    args[2] = Strings.toHexString(sender);
    args[3] = Strings.toHexString(recipient);
    args[4] = Strings.toString(amount);
    args[5] = Strings.toString(chainSelector);
    args[6] = Strings.toString(dstChainSelector);
    args[7] = Strings.toHexString(token);

    bytes32 reqId = sendRequest(args, srcJsCode);

    requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    requests[reqId].isPending = true;

    emit UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }
}
