// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IFunctions} from "./IConcero.sol";
import {ICCIP} from "./IConcero.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract CCombined is FunctionsClient, ConfirmedOwner, IFunctions, CCIPReceiver, ICCIP {
  using FunctionsRequest for FunctionsRequest.Request;
  using Strings for uint256;
  using Strings for uint64;
  using Strings for address;
  using Strings for bytes32;

  bytes32 private immutable donId;
  uint64 private immutable subscriptionId;
  uint64 private immutable chainSelector;
  address private immutable s_linkToken;
  uint8 private donHostedSecretsSlotID;
  uint64 private donHostedSecretsVersion;
  address public externalContract; // todo: remove this, we need a mapping of allowlisted external contracts for all chains, not one

  mapping(bytes32 => Transaction) public transactions;
  mapping(bytes32 => Request) public requests;

  /* todo: allowlisted src + dst chains can be combined into one two-dimensional mapping like so:
      this will still use one SLOAD but would remove the need for two separate mappings
    mapping[uint64][uint64] public allowListedChains;
    and then use it like so:
    modifier onlyAllowListedChain(uint64 _chainSelector, uint64 _chainType) {
      if (!allowListedChains[_chainType][_chainSelector]) revert ChainNotAllowed(_chainSelector);
      _;
    }
  */

  mapping(uint64 => bool) public allowListedDstChains;
  mapping(uint64 => bool) public allowListedSrcChains;
  mapping(address => bool) internal allowlist; //todo: remove this, instead use allowedSenderContracts & allowedDstContracts.
  // ideally combine allowlisted contracts for both src and destination chains into one mapping
  // like so : mapping[uint64][address] public allowedContracts;
  mapping(uint64 => address) public dstConceroCCIPContracts;

  //todo: can be turned into an npm package to save on js code size
  string private constant srcJsCode =
    "const { createWalletClient, custom } = await import('npm:viem'); const { privateKeyToAccount } = await import('npm:viem/accounts'); const { polygonMumbai, avalancheFuji } = await import('npm:viem/chains'); const [contractAddress, ccipMessageId, sender, recipient, amount, srcChainSelector, dstChainSelector, token] = args; const chainSelectors = {  '12532609583862916517': {   url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`,   chain: polygonMumbai,  },  '14767482510784806043': {   url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,   chain: avalancheFuji,  }, }; const abi = [  {   name: 'addUnconfirmedTX',   type: 'function',   inputs: [    { type: 'bytes32', name: 'ccipMessageId' },    { type: 'address', name: 'sender' },    { type: 'address', name: 'recipient' },    { type: 'uint256', name: 'amount' },    { type: 'uint64', name: 'srcChainSelector' },    { type: 'address', name: 'token' },   ],   outputs: [],  }, ]; try {  const account = privateKeyToAccount('0x' + secrets.WALLET_PRIVATE_KEY);  const walletClient = createWalletClient({   account,   chain: chainSelectors[dstChainSelector].chain,   transport: custom({    async request({ method, params }) {     if (method === 'eth_chainId') return chainSelectors[dstChainSelector].chain.id;     if (method === 'eth_estimateGas') return '0x3d090';     if (method === 'eth_maxPriorityFeePerGas') return '0x3b9aca00';     const response = await Functions.makeHttpRequest({      url: chainSelectors[dstChainSelector].url,      method: 'post',      headers: { 'Content-Type': 'application/json' },      data: { jsonrpc: '2.0', id: 1, method, params },     });     return response.data.result;    },   }),  });  const hash = await walletClient.writeContract({   abi,   functionName: 'addUnconfirmedTX',   address: contractAddress,   args: [ccipMessageId, sender, recipient, amount, BigInt(srcChainSelector), token],   gas: 1000000n,  });  return Functions.encodeString(hash); } catch (err) {  return Functions.encodeString('error'); }";
  string private constant dstJsCode =
    "const ethers = await import('npm:ethers@6.10.0'); const [srcContractAddress, messageId] = args; const params = {  url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`,  method: 'POST',  headers: {   'Content-Type': 'application/json',  },  data: {   jsonrpc: '2.0',   method: 'eth_getLogs',   id: 1,   params: [    {     address: srcContractAddress,     topics: [null, messageId],     fromBlock: 'earliest',     toBlock: 'latest',    },   ],  }, }; const response = await Functions.makeHttpRequest(params); const { data } = response; if (data?.error || !data?.result) {  throw new Error('Error fetching logs'); } const abi = ['event CCIPSent(bytes32 indexed, address, address, address, uint256, uint64)']; const contract = new ethers.Interface(abi); const log = {  topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]],  data: data.result[0].data, }; const decodedLog = contract.parseLog(log); const croppedArgs = args.slice(1); for (let i = 0; i < decodedLog.args.length; i++) {  if (decodedLog.args[i].toString().toLowerCase() !== croppedArgs[i].toString().toLowerCase()) {   throw new Error('Message ID does not match the event log');  } } return Functions.encodeUint256(BigInt(messageId));";

  modifier onlyAllowListedDstChain(uint64 _dstChainSelector) {
    if (!allowListedDstChains[_dstChainSelector]) revert DestinationChainNotAllowed(_dstChainSelector);
    _;
  }

  //todo: shall we remove combined modifiers and instead use two separate ones?
  modifier onlyAllowlistedSenderAndChainSelector(uint64 _sourceChainSelector, address _sender) {
    if (!allowListedSrcChains[_sourceChainSelector]) revert SourceChainNotAllowed(_sourceChainSelector);
    if (!allowlist[_sender]) revert SenderNotAllowed(_sender);
    _;
  }

  //todo: we can remove this and simply check for address(0) in the function
  modifier validateReceiver(address _receiver) {
    if (_receiver == address(0)) revert InvalidReceiverAddress();
    _;
  }

  modifier tokenAmountSufficiency(address _token, uint256 _amount) {
    require(IERC20(_token).balanceOf(msg.sender) >= _amount, "Insufficient balance");
    _;
  }

  modifier onlyAllowListedSenders() {
    if (!allowlist[msg.sender]) revert NotAllowed();
    _;
  }

  constructor(
    address _link,
    address _ccipRouter,
    address _functionsRouter,
    bytes32 _donId,
    uint64 _subscriptionId,
    uint64 _donHostedSecretsVersion,
    uint64 _chainSelector
  ) FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) CCIPReceiver(_ccipRouter) {
    s_linkToken = _link;
    donId = _donId;
    subscriptionId = _subscriptionId;
    donHostedSecretsVersion = _donHostedSecretsVersion;
    allowlist[msg.sender] = true;
    chainSelector = _chainSelector;
  }

  // setters
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

  function setExternalContract(address _externalContract) external onlyOwner {
    externalContract = _externalContract;
  }

  // DELETE IN PRODUCTION! TESTING ONLY
  function deleteTransaction(bytes32 ccipMessageId) external onlyOwner {
    delete transactions[ccipMessageId];
  }

  //ccip
  function setAllowDestinationChain(uint64 _dstChainSelector, bool allowed) external onlyOwner {
    allowListedDstChains[_dstChainSelector] = allowed;
  }

  function setAllowSourceChain(uint64 _srcChainSelector, bool allowed) external onlyOwner {
    allowListedSrcChains[_srcChainSelector] = allowed;
  }

  function setDstConceroCCIPContract(uint64 _chainSelector, address _dstConceroCCIPContract) external onlyOwner {
    dstConceroCCIPContracts[_chainSelector] = _dstConceroCCIPContract;
  }

  //ccip internal
  function _sendTokenPayLink(
    uint64 _destinationChainSelector,
    address _receiver,
    address _token,
    uint256 _amount
  ) internal onlyAllowListedDstChain(_destinationChainSelector) validateReceiver(_receiver) returns (bytes32 messageId) {
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _token, _amount, s_linkToken, _destinationChainSelector);

    IRouterClient router = IRouterClient(this.getRouter());
    uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);
    if (fees > IERC20(s_linkToken).balanceOf(address(this))) revert NotEnoughBalance(IERC20(s_linkToken).balanceOf(address(this)), fees);
    IERC20(s_linkToken).approve(address(router), fees);
    IERC20(_token).approve(address(router), _amount);
    messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);
    emit CCIPSent(messageId, msg.sender, _receiver, _token, _amount, _destinationChainSelector);
    return messageId;
  }

  function _buildCCIPMessage(
    address _receiver,
    address _token,
    uint256 _amount,
    address _feeToken,
    uint64 _destinationChainSelector
  ) private view returns (Client.EVM2AnyMessage memory) {
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = Client.EVMTokenAmount({token: _token, amount: _amount});

    return
      Client.EVM2AnyMessage({
        receiver: abi.encode(dstConceroCCIPContracts[_destinationChainSelector]),
        data: abi.encode(_receiver),
        tokenAmounts: tokenAmounts,
        extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 200_000})),
        feeToken: _feeToken
      });
  }

  function _ccipReceive(
    Client.Any2EVMMessage memory any2EvmMessage
  ) internal override onlyAllowlistedSenderAndChainSelector(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) {
    emit CCIPReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector,
      abi.decode(any2EvmMessage.sender, (address)),
      abi.decode(any2EvmMessage.data, (address)),
      any2EvmMessage.destTokenAmounts[0].token,
      any2EvmMessage.destTokenAmounts[0].amount
    );
  }

  function startTransaction(
    address _token,
    uint256 _amount,
    uint64 _destinationChainSelector,
    address _receiver
  ) external payable tokenAmountSufficiency(_token, _amount) {
    //todo: maybe move to OZ safeTransfer (but research needed)
    bool isOK = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    require(isOK, "Transfer failed");
    bytes32 ccipMessageId = _sendTokenPayLink(_destinationChainSelector, _receiver, _token, _amount);
    sendUnconfirmedTX(ccipMessageId, msg.sender, _receiver, _amount, _destinationChainSelector, _token);
  }

  function sendTokenToEoa(bytes32 _ccipMessageId, address _sender, address _recipient, address _token, uint256 _amount) internal {
    bool isOk = IERC20(_token).transfer(_recipient, _amount);
    require(isOk, "Transfer failed");
    emit TXReleased(_ccipMessageId, _sender, _recipient, _token, _amount);
  }

  function withdraw(address _owner) public onlyOwner {
    uint256 amount = address(this).balance;
    if (amount == 0) revert NothingToWithdraw();
    (bool sent, ) = _owner.call{value: amount}("");
    if (!sent) revert FailedToWithdrawEth(msg.sender, _owner, amount);
  }

  function withdrawToken(address _owner, address _token) public onlyOwner {
    uint256 amount = IERC20(_token).balanceOf(address(this));
    if (amount == 0) revert NothingToWithdraw();
    IERC20(_token).transfer(_owner, amount);
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
    /*
    todo: Strings usage may not be required here. Consider ways of passing data without converting to string
      like so:
      bytes memory args = abi.encode(
        externalContract,
        ccipMessageId,
        sender,
        recipient,
        token,
        amount,
        chainSelector,
        srcChainSelector
      );
      function sendRequest(bytes memory args string memory jsCode)
    */
    args[0] = Strings.toHexString(externalContract);
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
      if (err.length > 0) return;
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

    //todo: use token mapping either JS code instead of here
    if (transaction.token == 0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40) {
      tokenToSend = 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4;
    } else if (transaction.token == 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4) {
      tokenToSend = 0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40;
    }
    sendTokenToEoa(ccipMessageId, transaction.sender, transaction.recipient, tokenToSend, transaction.amount);
  }

  function sendUnconfirmedTX(bytes32 ccipMessageId, address sender, address recipient, uint256 amount, uint64 dstChainSelector, address token) internal {
    if (externalContract == address(0)) revert("externalContract address not set");

    string[] memory args = new string[](8);
    //todo: Strings usage may not be required here. Consider ways of passing data without converting to string
    args[0] = Strings.toHexString(externalContract);
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
