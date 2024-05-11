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

  bytes32 private immutable donId;
  uint64 private immutable subscriptionId;

  uint8 private donHostedSecretsSlotID;
  uint64 private donHostedSecretsVersion;

  mapping(bytes32 => Transaction) public transactions;
  mapping(bytes32 => Request) public requests;
  mapping(uint64 => uint256) public lastGasPrices; // chain selector => last gas price in wei

  string private constant srcJsCode =
    "const ethers = await import('npm:ethers@6.10.0'); const [ dstContractAddress, ccipMessageId, sender, recipient, amount, srcChainSelector, dstChainSelector, token, blockNumber, ] = args; const chainSelectors = { '14767482510784806043': { urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`], chainId: '0xa869', }, '16015286601757825753': { urls: [ `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://ethereum-sepolia-rpc.publicnode.com', 'https://ethereum-sepolia.blockpi.network/v1/rpc/public', ], chainId: '0xaa36a7', }, '3478487238524512106': { urls: [ `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://arbitrum-sepolia.blockpi.network/v1/rpc/public', 'https://arbitrum-sepolia-rpc.publicnode.com', ], chainId: '0x66eee', }, '10344971235874465080': { urls: [ `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`, 'https://base-sepolia.blockpi.network/v1/rpc/public', 'https://base-sepolia-rpc.publicnode.com', ], chainId: '0x14a34', }, '5224473277236331295': { urls: [ `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://optimism-sepolia.blockpi.network/v1/rpc/public', 'https://optimism-sepolia-rpc.publicnode.com', ], chainId: '0xaa37dc', }, }; const sleep = ms => new Promise(resolve => setTimeout(resolve, ms)); let nonce = 0; let retries = 0; let gasPrice; let maxPriorityFeePerGas; const sendTransaction = async (contract, signer, txOptions) => { try { const transaction = await contract.transactions(ccipMessageId); if (transaction[1] !== '0x0000000000000000000000000000000000000000') return; await contract.addUnconfirmedTX( ccipMessageId, sender, recipient, amount, srcChainSelector, token, blockNumber, txOptions, ); } catch (err) { if (retries >= 3) { throw new Error('retries reached the limit ' + err.message.slice(0, 200)); } const {message, code} = err; if (code === 'NONCE_EXPIRED' || code === 'REPLACEMENT_UNDERPRICED') { await sleep(1000 + Math.random() * 1000); retries++; await sendTransaction(contract, signer, { ...txOptions, nonce: nonce++, }); } if (code === 'UNKNOWN_ERROR' && message.include('already known')) { return; } throw new Error(err.message.slice(0, 255)); } }; try { class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider { constructor(url) { super(url); this.url = url; } async _send(payload) { if (payload.method === 'eth_estimateGas') { return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}]; } if (payload.method === 'eth_chainId') { return [{jsonrpc: '2.0', id: payload.id, result: chainSelectors[dstChainSelector].chainId}]; } if ( payload[0]?.method === 'eth_gasPrice' && payload[1].method === 'eth_maxPriorityFeePerGas' && payload.length === 2 ) { return [ {jsonrpc: '2.0', id: payload[0].id, result: gasPrice, method: 'eth_gasPrice'}, {jsonrpc: '2.0', id: payload[1].id, result: maxPriorityFeePerGas, method: 'eth_maxPriorityFeePerGas'}, ]; } if (payload[0]?.id === 1 && payload[0].method === 'eth_chainId' && payload[1].id === 2 && payload.length === 2) { return [ {jsonrpc: '2.0', method: 'eth_chainId', id: 1, result: chainSelectors[dstChainSelector].chainId}, {jsonrpc: '2.0', method: 'eth_getBlockByNumber', id: 2, result: chainSelectors[dstChainSelector].chainId}, ]; } let resp = await fetch(this.url, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload), }); const res = await resp.json(); if (res.length === undefined) { return [res]; } return res; } } const fallbackProviders = chainSelectors[dstChainSelector].urls.map(url => { return { provider: new FunctionsJsonRpcProvider(url), priority: Math.random(), stallTimeout: 5000, weight: 1, }; }); const provider = new ethers.FallbackProvider(fallbackProviders, null, {quorum: 1}); const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider); const signer = wallet.connect(provider); const abi = [ 'function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external', 'function transactions(bytes32) view returns (bytes32, address, address, uint256, uint8, uint64, bool)', ]; const contract = new ethers.Contract(dstContractAddress, abi, signer); const feeData = await provider.getFeeData(); nonce = await provider.getTransactionCount(wallet.address); gasPrice = feeData.gasPrice; maxPriorityFeePerGas = feeData.maxPriorityFeePerGas; await sendTransaction(contract, signer, { gasPrice, nonce, }); const srcChainProvider = new FunctionsJsonRpcProvider(chainSelectors[srcChainSelector].urls[0]); const srcGasPrice = Functions.encodeUint256(BigInt((await provider.getFeeData()).gasPrice)); const dstGasPrice = Functions.encodeUint256(BigInt(gasPrice)); const encodedDstChainSelector = Functions.encodeUint256(BigInt(dstChainSelector)); const res = new Uint8Array(srcGasPrice.length + dstGasPrice.length + encodedDstChainSelector.length); res.set(srcGasPrice); res.set(dstGasPrice, srcGasPrice.length); res.set(encodedDstChainSelector, srcGasPrice.length + dstGasPrice.length); return res; } catch (error) { throw new Error(error.message.slice(0, 255));}";
  string private constant dstJsCode =
    "try { const ethers = await import('npm:ethers@6.10.0'); const sleep = ms => new Promise(resolve => setTimeout(resolve, ms)); const [srcContractAddress, srcChainSelector, _, ...eventArgs] = args; const messageId = eventArgs[0]; const chainMap = { '14767482510784806043': { urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`], confirmations: 3n, chainId: '0xa869', }, '16015286601757825753': { urls: [ `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://ethereum-sepolia-rpc.publicnode.com', 'https://ethereum-sepolia.blockpi.network/v1/rpc/public', ], confirmations: 3n, chainId: '0xaa36a7', }, '3478487238524512106': { urls: [ `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://arbitrum-sepolia.blockpi.network/v1/rpc/public', 'https://arbitrum-sepolia-rpc.publicnode.com', ], confirmations: 3n, chainId: '0x66eee', }, '10344971235874465080': { urls: [ `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`, 'https://base-sepolia.blockpi.network/v1/rpc/public', 'https://base-sepolia-rpc.publicnode.com', ], confirmations: 3n, chainId: '0x14a34', }, '5224473277236331295': { urls: [ `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://optimism-sepolia.blockpi.network/v1/rpc/public', 'https://optimism-sepolia-rpc.publicnode.com', ], confirmations: 3n, chainId: '0xaa37dc', }, }; class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider { constructor(url) { super(url); this.url = url; } async _send(payload) { if (payload.method === 'eth_chainId') { return [{jsonrpc: '2.0', id: payload.id, result: chainMap[srcChainSelector].chainId}]; } const resp = await fetch(this.url, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload), }); const result = await resp.json(); if (payload.length === undefined) { return [result]; } return result; } } const fallBackProviders = chainMap[srcChainSelector].urls.map(url => { return { provider: new FunctionsJsonRpcProvider(url), priority: Math.random(), stallTimeout: 2000, weight: 1, }; }); const provider = new ethers.FallbackProvider(fallBackProviders, null, {quorum: 1}); let latestBlockNumber = BigInt(await provider.getBlockNumber()); const ethersId = ethers.id('CCIPSent(bytes32,address,address,uint8,uint256,uint64)'); const logs = await provider.getLogs({ address: srcContractAddress, topics: [ethersId, messageId], fromBlock: latestBlockNumber - 1000n, toBlock: latestBlockNumber, }); if (!logs.length) { throw new Error('No logs found'); } const log = logs[0]; const abi = ['event CCIPSent(bytes32 indexed, address, address, uint8, uint256, uint64)']; const contract = new ethers.Interface(abi); const logData = { topics: [ethersId, log.topics[1]], data: log.data, }; const decodedLog = contract.parseLog(logData); for (let i = 0; i < decodedLog.length; i++) { if (decodedLog.args[i].toString().toLowerCase() !== eventArgs[i].toString().toLowerCase()) { throw new Error('Message ID does not match the event log'); } } const logBlockNumber = BigInt(log.blockNumber); while (latestBlockNumber - logBlockNumber < chainMap[srcChainSelector].confirmations) { latestBlockNumber = BigInt(await provider.getBlockNumber()); await sleep(5000); } if (latestBlockNumber - logBlockNumber < chainMap[srcChainSelector].confirmations) { throw new Error('Not enough confirmations'); } return Functions.encodeUint256(BigInt(messageId)); } catch (error) { throw new Error(error.message.slice(0, 255));}";

  modifier onlyMessenger() {
    if (!messengerContracts[msg.sender]) revert NotMessenger(msg.sender);
    _;
  }

  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex
  ) FunctionsClient(_functionsRouter) ConceroCommon(_chainSelector, _chainIndex) {
    donId = _donId;
    subscriptionId = _subscriptionId;
    donHostedSecretsVersion = _donHostedSecretsVersion;
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    donHostedSecretsVersion = _version;
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
    args[0] = Strings.toHexString(conceroContracts[srcChainSelector]);
    args[1] = Strings.toString(srcChainSelector);
    args[2] = Strings.toHexString(blockNumber);
    args[3] = bytes32ToString(ccipMessageId);
    args[4] = Strings.toHexString(sender);
    args[5] = Strings.toHexString(recipient);
    args[6] = Strings.toString(uint(token));
    args[7] = Strings.toString(amount);
    args[8] = Strings.toString(chainSelector);

    bytes32 reqId = sendRequest(args, dstJsCode);
    requests[reqId].requestType = RequestType.checkTxSrc;
    requests[reqId].isPending = true;
    requests[reqId].ccipMessageId = ccipMessageId;
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
      sendTokenToEoa(request.ccipMessageId, transaction.sender, transaction.recipient, getToken(transaction.token), transaction.amount);
    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      if (response.length != 128) {
        return;
      }

      (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector) = abi.decode(response, (uint256, uint256, uint256));
      lastGasPrices[chainSelector] = srcGasPrice;
      lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    }
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
    args[0] = Strings.toHexString(conceroContracts[dstChainSelector]);
    args[1] = bytes32ToString(ccipMessageId);
    args[2] = Strings.toHexString(sender);
    args[3] = Strings.toHexString(recipient);
    args[4] = Strings.toString(amount);
    args[5] = Strings.toString(chainSelector);
    args[6] = Strings.toString(dstChainSelector);
    args[7] = Strings.toString(uint(token));
    args[8] = Strings.toHexString(block.number);

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
