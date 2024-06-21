// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {IConceroPool} from "./Interfaces/IConceroPool.sol";

error ConceroAutomation_CallerNotAllowed(address caller);

contract ConceroAutomation is AutomationCompatibleInterface, FunctionsClient, Ownable {
  ///////////////////////
  ///TYPE DECLARATIONS///
  ///////////////////////
  using FunctionsRequest for FunctionsRequest.Request;

  struct PerformWithdrawRequest {
    address liquidityProvider;
    uint256 amount;
  }

  ///////////////////////////////////////////////////////////
  //////////////////////// VARIABLES ////////////////////////
  ///////////////////////////////////////////////////////////
  ///////////////
  ///CONSTANTS///
  ///////////////
  ///@notice Chainlink Functions Gas Limit
  uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 300_000;
  ///@notice Chainlink Function Gas Overhead
  uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000;
  ///@notice Chainlink Src Response Length
  uint8 internal constant CL_SRC_RESPONSE_LENGTH = 192;
  ///@notice JS Code for Chainlink Functions
  string internal constant PERFORM_JS_CODE =
    "try { const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js'; const [t, p] = await Promise.all([ fetch(u), fetch( `https://raw.githubusercontent.com/concero/contracts-ccip/full-infra-functions/packages/hardhat/tasks/CLFScripts/dist/${BigInt(bytesArgs[2]) === 1n ? 'DST' : 'SRC'}.min.js`, ), ]); const [e, c] = await Promise.all([t.text(), p.text()]); const g = async s => { return ( '0x' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))) .map(v => ('0' + v.toString(16)).slice(-2).toLowerCase()) .join('') ); }; const r = await g(c); const x = await g(e); const b = bytesArgs[0].toLowerCase(); const o = bytesArgs[1].toLowerCase(); if (r === b && x === o) { const ethers = new Function(e + '; return ethers;')(); return await eval(c); } throw new Error(`${r}!=${b}||${x}!=${o}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Chainlink Function Don ID
  bytes32 private immutable i_donId;
  ///@notice Chainlink Functions Protocol Subscription ID
  uint64 private immutable i_subscriptionId;
  ///@notice MasterPool address
  address private immutable i_masterPool;
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 private immutable i_donHostedSecretsSlotId;

  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
  ///@notice variable to store the automation keeper address
  address public s_forwarderAddress;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 internal s_hashSum;
  ///@notice variable to store the Chainlink Function Destination Hashsum
  bytes32 internal s_dstJsHashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 internal s_ethersHashSum;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array to store the withdraw requests of users
  IConceroPool.WithdrawRequests[] public s_pendingWithdrawRequestsCLA;

  ///@notice Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 requestId => PerformWithdrawRequest) public s_requests;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a new request is added
  event ConceroAutomation_RequestAdded(IConceroPool.WithdrawRequests request);
  ///@notice event emitted when the Pool Address is updated
  event ConceroAutomation_PoolAddressUpdated(address pool);
  ///@notice event emitted when the Keeper Address is updated
  event ConceroAutomation_ForwarderAddressUpdated(address forwarderAddress);
  ///@notice event emitted when a Chainlink Functions request is not fulfilled
  event FunctionsRequestError(bytes32 requestId);
  ///@notice event emitted when an upkeep is performed
  event ConceroAutomation_UpkeepPerformed(bytes32 reqId);
  ///@notice event emitted when the Don Secret is Updated
  event ConceroAutomation_DonSecretVersionUpdated(uint64 version);
  ///@notice event emitted when the hashSum of Chainlink Function is updated
  event ConceroAutomation_HashSumUpdated(bytes32 previousValue, bytes32 hashSum);
  ///@notice event emitted when the Ethers HashSum is updated
  event ConceroAutomation_EthersHashSumUpdated(bytes32 previousValue, bytes32 hashSum);

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  constructor(
    bytes32 _donId,
    uint64 _subscriptionId,
    uint8 _slotId,
    uint64 _secretsVersion,
    bytes32 _hashSum,
    bytes32 _dstJsHashSum,
    bytes32 _ethersHashSum,
    address _functionsRouter,
    address _masterPool,
    address _owner
  ) FunctionsClient(_functionsRouter) Ownable(_owner) {
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    i_donHostedSecretsSlotId = _slotId;
    i_masterPool = _masterPool;
    s_donHostedSecretsVersion = _secretsVersion;
    s_hashSum = _hashSum;
    s_dstJsHashSum = _dstJsHashSum;
    s_ethersHashSum = _ethersHashSum;
  }

  /**
   * @notice Function to set the Chainlink Automation Forwarder
   * @param _forwarderAddress the unique forward address
   * @dev this address will be used inside of revert statements
   */
  function setForwarderAddress(address _forwarderAddress) external onlyOwner {
    s_forwarderAddress = _forwarderAddress;

    emit ConceroAutomation_ForwarderAddressUpdated(_forwarderAddress);
  }

  /**
   * @notice Function to set the Don Secrects Version from Chainlink Functions
   * @param _version the version
   * @dev this functions was used inside of ConceroFunctions
   */
  function setDonHostedSecretsVersion(uint64 _version) external onlyOwner {
    s_donHostedSecretsVersion = _version;

    emit ConceroAutomation_DonSecretVersionUpdated(_version);
  }

  /**
   * @notice Function to set the Source JS code for Chainlink Functions
   * @param _hashSum  the JsCode
   * @dev this functions was used inside of ConceroFunctions
   */
  function setSrcJsHashSum(bytes32 _hashSum) external onlyOwner {
    bytes32 previousValue = s_dstJsHashSum;

    s_hashSum = _hashSum;

    emit ConceroAutomation_HashSumUpdated(previousValue, _hashSum);
  }

  /**
   * @notice Function to set the Ethers JS code for Chainlink Functions
   * @param _hashSum the JsCode
   * @dev this functions was used inside of ConceroFunctions
   */
  function setEthersHashSum(bytes32 _hashSum) external payable onlyOwner {
    bytes32 previousValue = s_ethersHashSum;
    s_ethersHashSum = _hashSum;
    emit ConceroAutomation_EthersHashSumUpdated(previousValue, _hashSum);
  }

  /**
   * @notice Function to add new withdraw requests to CLA monitoring system
   * @param _request the WithdrawRequests populated struct
   * @dev this function should only be called by the ConceroPool.sol
   */
  function addPendingWithdrawal(IConceroPool.WithdrawRequests memory _request) external {
    if (i_masterPool != msg.sender) revert ConceroAutomation_CallerNotAllowed(msg.sender);

    s_pendingWithdrawRequestsCLA.push(_request);

    emit ConceroAutomation_RequestAdded(_request);
  }

  /**
   * @notice Chainlink Automation Function to check for requests with fulfilled conditions
   * We don't use the calldata
   * @return _upkeepNeeded it will return true, if the time condition is reached
   * @return _performData the payload we need to send through performUpkeep to Chainlink functions.
   * @dev this function must be called only by the Chainlink Forwarder unique address
   */
  function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool _upkeepNeeded, bytes memory _performData) {
    if (msg.sender != s_forwarderAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);

    uint256 requestsNumber = s_pendingWithdrawRequestsCLA.length;

    for (uint256 i; i < requestsNumber; ++i) {
      if (block.timestamp > s_pendingWithdrawRequestsCLA[i].deadline) {
        _performData = abi.encode(
          s_pendingWithdrawRequestsCLA[i].liquidityProvider, //address
          s_pendingWithdrawRequestsCLA[i].amountToRequest //uint256
        );
        _upkeepNeeded = true;
      }
    }
  }

  /**
   * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
   * @param _performData the performData encoded in checkUpkeep function
   * @dev this function must be called only by the Chainlink Forwarder unique address
   */
  function performUpkeep(bytes calldata _performData) external override {
    if (msg.sender != s_forwarderAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);

    (address sender, uint256 amountToRequest) = abi.decode(_performData, (address, uint256));

    bytes[] memory args = new bytes[](4); //@Nikita.
    args[0] = abi.encodePacked(s_hashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);
    args[2] = abi.encodePacked(sender); //We need to send this as data through CCIP to updated the MasterPool storage.
    args[3] = abi.encodePacked(amountToRequest); //Amount is the same for all pools

    bytes32 reqId = _sendRequest(args, PERFORM_JS_CODE); //@No JS code yet

    s_requests[reqId] = PerformWithdrawRequest({liquidityProvider: sender, amount: amountToRequest});

    emit ConceroAutomation_UpkeepPerformed(reqId);
  }

  /**
   * @notice Function to send a Request to Chainlink Functions
   * @param _args the arguments for the request as bytes array
   * @param _jsCode the JScode that will be executed.
   */
  function _sendRequest(bytes[] memory _args, string memory _jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(_jsCode);
    req.addDONHostedSecrets(i_donHostedSecretsSlotId, s_donHostedSecretsVersion);
    req.setBytesArgs(_args);
    return _sendRequest(req.encodeCBOR(), i_subscriptionId, CL_FUNCTIONS_CALLBACK_GAS_LIMIT, i_donId);
  }

  /**
   * @notice Chainlink Functions fallback function
   * @param requestId the ID of the request sent
   * @param response the response of the request sent
   * @param err the error of the request sent
   * @dev response & err will never be empty or populated at same time.
   */
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    PerformWithdrawRequest storage request = s_requests[requestId];

    if (err.length > 0) {
      emit FunctionsRequestError(requestId);
      return;
    }

    bool fulfilled = abi.decode(response, (bool)); //Is that simple ? Looks wrong.
    if (fulfilled == true) {
      uint256 requestsNumber = s_pendingWithdrawRequestsCLA.length;

      for (uint256 i; i < requestsNumber; ++i) {
        if (s_pendingWithdrawRequestsCLA[i].liquidityProvider == request.liquidityProvider) {
          s_pendingWithdrawRequestsCLA[i] = s_pendingWithdrawRequestsCLA[s_pendingWithdrawRequestsCLA.length - 1];
          s_pendingWithdrawRequestsCLA.pop();
        }
      }
    }
  }
}
