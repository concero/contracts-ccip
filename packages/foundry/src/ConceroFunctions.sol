// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFunctions} from "./IConcero.sol";
import {Concero} from "./Concero.sol";
import {ConceroPool} from "./ConceroPool.sol";
import {ConceroCommon} from "./ConceroCommon.sol";

error ConceroFunctions_TxDoesNotExist();
error ConceroFunctions_TxAlreadyConfirmed();
error ConceroFunctions_AddressNotSet();

contract ConceroFunctions is FunctionsClient, IFunctions, ConceroCommon {
  using SafeERC20 for IERC20;

  using FunctionsRequest for FunctionsRequest.Request;
  using Strings for uint256;
  using Strings for uint64;
  using Strings for address;
  using Strings for bytes32;

  uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000;

  bytes32 private immutable i_donId;
  uint64 private immutable i_subscriptionId;

  uint8 private s_donHostedSecretsSlotId;
  uint64 private s_donHostedSecretsVersion;

  bytes32 private s_srcJsHashSum;
  bytes32 private s_dstJsHashSum;

  ConceroPool private s_pool;

  mapping(bytes32 => Transaction) public s_transactions;
  mapping(bytes32 => Request) public s_requests;
  mapping(uint64 => uint256) public s_lastGasPrices; // chain selector => last gas price in wei

  string private constant srcJsCode =
    "const ethers = await import('npm:ethers@6.10.0'); const [ dstContractAddress, ccipMessageId, sender, recipient, amount, srcChainSelector, dstChainSelector, token, blockNumber, ] = args; const chainSelectors = { '14767482510784806043': { urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`], chainId: '0xa869', }, '16015286601757825753': { urls: [ `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://ethereum-sepolia-rpc.publicnode.com', 'https://ethereum-sepolia.blockpi.network/v1/rpc/public', ], chainId: '0xaa36a7', }, '3478487238524512106': { urls: [ `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://arbitrum-sepolia.blockpi.network/v1/rpc/public', 'https://arbitrum-sepolia-rpc.publicnode.com', ], chainId: '0x66eee', }, '10344971235874465080': { urls: [ `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`, 'https://base-sepolia.blockpi.network/v1/rpc/public', 'https://base-sepolia-rpc.publicnode.com', ], chainId: '0x14a34', }, '5224473277236331295': { urls: [ `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://optimism-sepolia.blockpi.network/v1/rpc/public', 'https://optimism-sepolia-rpc.publicnode.com', ], chainId: '0xaa37dc', }, }; const sleep = ms => new Promise(resolve => setTimeout(resolve, ms)); let nonce = 0; let retries = 0; let gasPrice; const sendTransaction = async (contract, signer, txOptions) => { try { const transaction = await contract.transactions(ccipMessageId); if ((await contract.transactions(ccipMessageId))[1] !== '0x0000000000000000000000000000000000000000') return; await contract.addUnconfirmedTX( ccipMessageId, sender, recipient, amount, srcChainSelector, token, blockNumber, txOptions, ); } catch (err) { const {message, code} = err; if (retries >= 5) { throw new Error('retries reached the limit ' + err.message?.slice(0, 200)); } else if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low')) { await sleep(1000 + Math.random() * 1500); retries++; await sendTransaction(contract, signer, { ...txOptions, nonce: nonce++, }); } else if (code === 'UNKNOWN_ERROR' && message?.includes('already known')) { return; } else { throw new Error(err.message?.slice(0, 255)); } } }; try { class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider { constructor(url) { super(url); this.url = url; } async _send(payload) { if (payload.method === 'eth_estimateGas') { return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}]; } if (payload.method === 'eth_chainId') { return [{jsonrpc: '2.0', id: payload.id, result: chainSelectors[dstChainSelector].chainId}]; } let resp = await fetch(this.url, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload), }); const res = await resp.json(); if (res.length === undefined) { return [res]; } return res; } } const dstUrl = chainSelectors[dstChainSelector].urls[Math.floor(Math.random() * chainSelectors[dstChainSelector].urls.length)]; const provider = new FunctionsJsonRpcProvider(dstUrl); const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider); const signer = wallet.connect(provider); const abi = [ 'function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external', 'function transactions(bytes32) view returns (bytes32, address, address, uint256, uint8, uint64, bool)', ]; const contract = new ethers.Contract(dstContractAddress, abi, signer); const feeData = await provider.getFeeData(); nonce = await provider.getTransactionCount(wallet.address); gasPrice = feeData.gasPrice; await sendTransaction(contract, signer, { gasPrice, nonce, }); const srcUrl = chainSelectors[srcChainSelector].urls[Math.floor(Math.random() * chainSelectors[srcChainSelector].urls.length)]; const srcChainProvider = new FunctionsJsonRpcProvider(srcUrl); const srcGasPrice = Functions.encodeUint256(BigInt((await srcChainProvider.getFeeData()).gasPrice || 0)); const dstGasPrice = Functions.encodeUint256(BigInt(gasPrice || 0)); const encodedDstChainSelector = Functions.encodeUint256(BigInt(dstChainSelector || 0)); const res = new Uint8Array(srcGasPrice.length + dstGasPrice.length + encodedDstChainSelector.length); res.set(srcGasPrice); res.set(dstGasPrice, srcGasPrice.length); res.set(encodedDstChainSelector, srcGasPrice.length + dstGasPrice.length); return res; } catch (error) { const {message} = error; if (message?.includes('Exceeded maximum of 20 HTTP queries')) { return new Uint8Array(1); } else { throw new Error(message?.slice(0, 255));}}";
  string private constant dstJsCode =
    "try { const ethers = await import('npm:ethers@6.10.0'); const sleep = ms => new Promise(resolve => setTimeout(resolve, ms)); const [srcContractAddress, srcChainSelector, _, ...eventArgs] = args; const messageId = eventArgs[0]; const chainMap = { '14767482510784806043': { urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`], confirmations: 3n, chainId: '0xa869', }, '16015286601757825753': { urls: [ `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://ethereum-sepolia-rpc.publicnode.com', 'https://ethereum-sepolia.blockpi.network/v1/rpc/public', ], confirmations: 3n, chainId: '0xaa36a7', }, '3478487238524512106': { urls: [ `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://arbitrum-sepolia.blockpi.network/v1/rpc/public', 'https://arbitrum-sepolia-rpc.publicnode.com', ], confirmations: 3n, chainId: '0x66eee', }, '10344971235874465080': { urls: [ `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`, 'https://base-sepolia.blockpi.network/v1/rpc/public', 'https://base-sepolia-rpc.publicnode.com', ], confirmations: 3n, chainId: '0x14a34', }, '5224473277236331295': { urls: [ `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`, 'https://optimism-sepolia.blockpi.network/v1/rpc/public', 'https://optimism-sepolia-rpc.publicnode.com', ], confirmations: 3n, chainId: '0xaa37dc', }, }; class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider { constructor(url) { super(url); this.url = url; } async _send(payload) { if (payload.method === 'eth_chainId') { return [{jsonrpc: '2.0', id: payload.id, result: chainMap[srcChainSelector].chainId}]; } const resp = await fetch(this.url, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload), }); const result = await resp.json(); if (payload.length === undefined) { return [result]; } return result; } } const fallBackProviders = chainMap[srcChainSelector].urls.map(url => { return { provider: new FunctionsJsonRpcProvider(url), priority: Math.random(), stallTimeout: 2000, weight: 1, }; }); const provider = new ethers.FallbackProvider(fallBackProviders, null, {quorum: 1}); let latestBlockNumber = BigInt(await provider.getBlockNumber()); const ethersId = ethers.id('CCIPSent(bytes32,address,address,uint8,uint256,uint64)'); const logs = await provider.getLogs({ address: srcContractAddress, topics: [ethersId, messageId], fromBlock: latestBlockNumber - 1000n, toBlock: latestBlockNumber, }); if (!logs.length) { throw new Error('No logs found'); } const log = logs[0]; const abi = ['event CCIPSent(bytes32 indexed, address, address, uint8, uint256, uint64)']; const contract = new ethers.Interface(abi); const logData = { topics: [ethersId, log.topics[1]], data: log.data, }; const decodedLog = contract.parseLog(logData); for (let i = 0; i < decodedLog.length; i++) { if (decodedLog.args[i].toString().toLowerCase() !== eventArgs[i].toString().toLowerCase()) { throw new Error('Message ID does not match the event log'); } } const logBlockNumber = BigInt(log.blockNumber); while (latestBlockNumber - logBlockNumber < chainMap[srcChainSelector].confirmations) { latestBlockNumber = BigInt(await provider.getBlockNumber()); await sleep(5000); } if (latestBlockNumber - logBlockNumber < chainMap[srcChainSelector].confirmations) { throw new Error('Not enough confirmations'); } return Functions.encodeUint256(BigInt(messageId)); } catch (error) { throw new Error(error.message.slice(0, 255));}";

  modifier onlyMessenger() {
    if (!s_messengerContracts[msg.sender]) revert ConceroFunctions_NotMessenger(msg.sender);
    _;
  }

  constructor(
    address _functionsRouter,
    uint64 _donHostedSecretsVersion,
    bytes32 _donId,
    uint8 _donHostedSecretsSlotId,
    uint64 _subscriptionId,
    uint64 _chainSelector,
    uint _chainIndex
  ) FunctionsClient(_functionsRouter) ConceroCommon(_chainSelector, _chainIndex) {
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    s_donHostedSecretsVersion = _donHostedSecretsVersion;
    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;
  }

  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    uint64 previousValue = s_donHostedSecretsVersion;

    s_donHostedSecretsVersion = _version;

    emit ConceroFunctions_DonSecretVersionUpdated(previousValue, _version);
  }

  function setDonHostedSecretsSlotID(uint8 _donHostedSecretsSlotId) external onlyOwner {
    uint8 previousValue = s_donHostedSecretsSlotId;

    s_donHostedSecretsSlotId = _donHostedSecretsSlotId;

    emit ConceroFunctions_DonSlotIdUpdated(previousValue, _donHostedSecretsSlotId); 
  }

  function setDstJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_dstJsHashSum = _hashSum;

    emit ConceroFunctions_DestinationJsHashSumUpdated(previousValue, _hashSum);
  }

  function setSrcJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_srcJsHashSum = _hashSum;
    
    emit ConceroFunctions_SourceJsHashSumUpdated(previousValue, _hashSum);
  }

  //@New
  function setConceroPoolAddress(address payable _pool) external onlyOwner {
    address previousAddress = address(s_pool);

    s_pool = ConceroPool(_pool);

    emit ConceroFunctions_ConceroPoolAddressUpdated(previousAddress, _pool);
  }

  //@audit if updated to bytes[] memory. We can remove this guys
  function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
    bytes32 out;
    for (uint i = 0; i < 32; i++) {
      out |= bytes32(b[i] & 0xFF) >> (i * 8);
    }
    return out;
  }

  //@audit if updated to bytes[] memory. We can remove this guys
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
    Transaction memory transaction = s_transactions[ccipMessageId];
    if (transaction.sender != address(0)) revert ConceroFunctions_TXAlreadyExists(ccipMessageId, transaction.isConfirmed);
    
    s_transactions[ccipMessageId] = Transaction(ccipMessageId, sender, recipient, amount, token, srcChainSelector, false);

    //@audit bytes[] memory args = new bytes[](9)
    string[] memory args = new string[](10);
    //todo: use bytes
    //@audit = abi.encode(param);
    args[0] = bytes32ToString(s_srcJsHashSum);
    args[1] = Strings.toHexString(s_conceroContracts[srcChainSelector]);
    args[2] = Strings.toString(srcChainSelector);
    args[3] = Strings.toHexString(blockNumber);
    args[4] = bytes32ToString(ccipMessageId);
    args[5] = Strings.toHexString(sender);
    args[6] = Strings.toHexString(recipient);
    args[7] = Strings.toString(uint(token));
    args[8] = Strings.toString(amount);
    args[9] = Strings.toString(i_chainSelector);

    //Comment this out to local testing
    // bytes32 reqId = sendRequest(args, dstJsCode);
    
    //Comment this out after testing
    bytes32 reqId = ccipMessageId;

    s_requests[reqId].requestType = RequestType.checkTxSrc;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit ConceroFunctions_UnconfirmedTXAdded(ccipMessageId, sender, recipient, amount, token, srcChainSelector);
  }

  //@audit I think we can send bytes[] memory args instead of string[] memory args.
  //I just don't know yet if we need to pass anything different besides the setArgs function.
  function sendRequest(string[] memory args, string memory jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(jsCode);
    req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
    req.setArgs(args);
    return _sendRequest(req.encodeCBOR(), i_subscriptionId, CL_FUNCTIONS_CALLBACK_GAS_LIMIT, i_donId);
  }

  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    Request storage request = s_requests[requestId];

    if (!request.isPending) {
      revert ConceroFunctions_UnexpectedRequestID(requestId);
    }

    request.isPending = false;

    if (err.length > 0) {
      emit ConceroFunctions_FunctionsRequestError(request.ccipMessageId, requestId, uint8(request.requestType));
      return;
    }

    if (request.requestType == RequestType.checkTxSrc) {

      Transaction storage transaction = s_transactions[request.ccipMessageId];
      
      _confirmTX(request.ccipMessageId, transaction);

      uint256 amount = transaction.amount - getDstTotalFeeInUsdc(transaction.amount);

      //@audit
      //When receiving, we are taking the fee on top of the transfered money
      //Not on top of the initial money. So, we are "rounding down" against
      //the protocol and charging less than we should.
      address tokenReceived = getToken(transaction.token);

      if(tokenReceived == getToken(CCIPToken.usdc)){

        s_pool.orchestratorLoan(/*tokenReceived*/0xa0Cb889707d426A7A386870A03bc70d1b0697598, amount, transaction.recipient);

      } else {
        //@audit We need to call the DEX module here.
        // dexSwap.conceroEntry(passing the user address as receiver);
      }

    } else if (request.requestType == RequestType.addUnconfirmedTxDst) {
      //@audit what means this 96?
      if (response.length != 96) {
        return;
      }

      (uint256 dstGasPrice, uint256 srcGasPrice, uint256 dstChainSelector) = abi.decode(response, (uint256, uint256, uint256));

      s_lastGasPrices[i_chainSelector] = srcGasPrice;
      s_lastGasPrices[uint64(dstChainSelector)] = dstGasPrice;
    }
  }

  function getDstTotalFeeInUsdc(uint256 amount) public pure returns (uint256) {
    return amount / 1000;
    //@audit we can have loss of precision here?
  }

  function _confirmTX(bytes32 ccipMessageId, Transaction storage transaction) internal {
    if(transaction.sender == address(0)) revert ConceroFunctions_TxDoesNotExist();
    if(transaction.isConfirmed == true) revert ConceroFunctions_TxAlreadyConfirmed();

    transaction.isConfirmed = true;

    emit ConceroFunctions_TXConfirmed(ccipMessageId, transaction.sender, transaction.recipient, transaction.amount, transaction.token);
  }

  function _sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, CCIPToken token) internal {
    if (s_conceroContracts[dstChainSelector] == address(0)) revert ConceroFunctions_AddressNotSet();

    string[] memory args = new string[](9);
    //todo: Strings usage may not be required here. Consider ways of passing data without converting to string
    args[0] = bytes32ToString(s_dstJsHashSum);
    args[1] = Strings.toHexString(s_conceroContracts[dstChainSelector]);
    args[2] = bytes32ToString(ccipMessageId);
    args[3] = Strings.toHexString(sender);
    args[4] = Strings.toHexString(recipient);
    args[5] = Strings.toString(amount);
    args[6] = Strings.toString(i_chainSelector);
    args[7] = Strings.toString(dstChainSelector);
    args[8] = Strings.toString(uint256(token));
    args[9] = Strings.toHexString(block.number);

    bytes32 reqId = sendRequest(args, srcJsCode);
    s_requests[reqId].requestType = RequestType.addUnconfirmedTxDst;
    s_requests[reqId].isPending = true;
    s_requests[reqId].ccipMessageId = ccipMessageId;

    emit ConceroFunctions_UnconfirmedTXSent(ccipMessageId, sender, recipient, amount, token, dstChainSelector);
  }
}
