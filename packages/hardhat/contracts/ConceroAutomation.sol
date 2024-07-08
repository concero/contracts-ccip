// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import {IParentPool} from "./Interfaces/IParentPool.sol";

///@notice error emitted when the caller is not the owner.
error ConceroAutomation_CallerNotAllowed(address caller);
error ConceroAutomation_WithdrawAlreadyTriggered(address liquidityProvider);
error ConceroAutomation_CLFFallbackError(bytes32 requestId);

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
  uint256 public constant CL_FUNCTIONS_GAS_OVERHEAD = 185_000; //@audit do we need this? It's not being used.
  ///@notice JS Code for Chainlink Functions
  string internal constant JS_CODE =
    "try { const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js'; const q = 'https://raw.githubusercontent.com/concero/contracts-ccip/' + 'master' + '/packages/hardhat/tasks/CLFScripts/dist/pool/collectLiquidity.min.js'; const [t, p] = await Promise.all([fetch(u), fetch(q)]); const [e, c] = await Promise.all([t.text(), p.text()]); const g = async s => { return ( '0x' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))) .map(v => ('0' + v.toString(16)).slice(-2).toLowerCase()) .join('') ); }; const r = await g(c); const x = await g(e); const b = bytesArgs[0].toLowerCase(); const o = bytesArgs[1].toLowerCase(); if (r === b && x === o) { const ethers = new Function(e + '; return ethers;')(); return await eval(c); } throw new Error(`${r}!=${b}||${x}!=${o}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";

  ////////////////
  ///IMMUTABLES///
  ////////////////
  ///@notice Chainlink Function Don ID
  bytes32 private immutable i_donId;
  ///@notice Chainlink Functions Protocol Subscription ID
  uint64 private immutable i_subscriptionId;
  ///@notice MasterPool Proxy address
  address private immutable i_masterPoolProxy;

  /////////////////////
  ///STATE VARIABLES///
  /////////////////////
  ///@notice variable to store the automation keeper address
  address public s_forwarderAddress;
  ///@notice variable to store the Chainlink Function DON Secret Version
  uint64 internal s_donHostedSecretsVersion;
  ///@notice variable to store the Chainlink Function Source Hashsum
  bytes32 internal s_hashSum;
  ///@notice variable to store Ethers Hashsum
  bytes32 internal s_ethersHashSum;
  ///@notice variable to store the Chainlink Function DON Slot ID
  uint8 private s_donHostedSecretsSlotId;

  /////////////
  ///STORAGE///
  /////////////
  ///@notice array to store the withdraw requests of users
  address[] public s_pendingWithdrawRequestsCLA;

  ///@notice Mapping to keep track of Chainlink Functions requests
  mapping(bytes32 requestId => PerformWithdrawRequest) public s_functionsRequests;
  mapping(address => bool) public s_withdrawTriggered;

  ////////////////////////////////////////////////////////
  //////////////////////// EVENTS ////////////////////////
  ////////////////////////////////////////////////////////
  ///@notice event emitted when a new request is added
  event ConceroAutomation_RequestAdded(address);
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
  event ConceroAutomation_HashSumUpdated(bytes32 hashSum);
  ///@notice event emitted when the Ethers HashSum is updated
  event ConceroAutomation_EthersHashSumUpdated(bytes32 hashSum);

  /////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////FUNCTIONS//////////////////////////////////
  /////////////////////////////////////////////////////////////////////////////
  constructor(
    bytes32 _donId,
    uint64 _subscriptionId,
    uint8 _slotId,
    address _functionsRouter,
    address _masterPool,
    address _owner
  ) FunctionsClient(_functionsRouter) Ownable(_owner) {
    i_donId = _donId;
    i_subscriptionId = _subscriptionId;
    s_donHostedSecretsSlotId = _slotId;
    i_masterPoolProxy = _masterPool;
  }

  /**
   * @notice Function to add new withdraw requests to CLA monitoring system
   * @param _liquidityProvider the WithdrawRequests populated address
   * @dev this function should only be called by the ConceroPool.sol
   */
  function addPendingWithdrawal(address _liquidityProvider) external {
    if (i_masterPoolProxy != msg.sender) revert ConceroAutomation_CallerNotAllowed(msg.sender);

    s_pendingWithdrawRequestsCLA.push(_liquidityProvider);

    emit ConceroAutomation_RequestAdded(_liquidityProvider);
  }

  /**
   * @notice Chainlink Automation Function to check for requests with fulfilled conditions
   * We don't use the calldata
   * @return _upkeepNeeded it will return true, if the time condition is reached
   * @return _performData the payload we need to send through performUpkeep to Chainlink functions.
   * @dev this function must be called only by the Chainlink Forwarder unique address
   */
  function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool _upkeepNeeded, bytes memory _performData) {
    uint256 requestsNumber = s_pendingWithdrawRequestsCLA.length;

    for (uint256 i; i < requestsNumber; ++i) {
      address liquidityProvider = s_pendingWithdrawRequestsCLA[i];
      IParentPool.WithdrawRequests memory pendingRequest = IParentPool(i_masterPoolProxy).getPendingWithdrawRequest(liquidityProvider);

      if (s_withdrawTriggered[liquidityProvider] == false && block.timestamp > pendingRequest.deadline) {
        _performData = abi.encode(liquidityProvider, pendingRequest.amountToRequest);
        _upkeepNeeded = true;
      }
    }
  }

  // TODO: REMOVE IN PRODUCTION!!!!!!!!
  function deleteRequest(address _liquidityProvider) external onlyOwner {
    uint256 requestsNumber = s_pendingWithdrawRequestsCLA.length;

    for (uint256 i; i < requestsNumber; ++i) {
      if (s_pendingWithdrawRequestsCLA[i] == _liquidityProvider) {
        s_pendingWithdrawRequestsCLA[i] = s_pendingWithdrawRequestsCLA[s_pendingWithdrawRequestsCLA.length - 1];
        s_pendingWithdrawRequestsCLA.pop();
      }
    }

    s_withdrawTriggered[_liquidityProvider] = false;
  }

  /**
   * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
   * @param _performData the performData encoded in checkUpkeep function
   * @dev this function must be called only by the Chainlink Forwarder unique address
   */
  function performUpkeep(bytes calldata _performData) external override {
    if (msg.sender != s_forwarderAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);
    (address liquidityProvider, uint256 amountToRequest) = abi.decode(_performData, (address, uint256));

    if (s_withdrawTriggered[liquidityProvider] == true) {
      revert ConceroAutomation_WithdrawAlreadyTriggered(liquidityProvider);
    } else {
      s_withdrawTriggered[liquidityProvider] = true;
    }

    bytes[] memory args = new bytes[](4);
    args[0] = abi.encodePacked(s_hashSum);
    args[1] = abi.encodePacked(s_ethersHashSum);
    args[2] = abi.encodePacked(liquidityProvider);
    args[3] = abi.encodePacked(amountToRequest);

    bytes32 reqId = _sendRequest(args, JS_CODE);

    s_functionsRequests[reqId] = PerformWithdrawRequest({liquidityProvider: liquidityProvider, amount: amountToRequest});

    emit ConceroAutomation_UpkeepPerformed(reqId);
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
   * @notice Function to set the Don Secrets Version from Chainlink Functions
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
  function setJsHashSum(bytes32 _hashSum) external onlyOwner {
    s_hashSum = _hashSum;

    emit ConceroAutomation_HashSumUpdated(_hashSum);
  }

  /**
   * @notice Function to set the Ethers JS code for Chainlink Functions
   * @param _hashSum the JsCode
   * @dev this functions was used inside of ConceroFunctions
   */
  function setEthersHashSum(bytes32 _hashSum) external payable onlyOwner {
    s_ethersHashSum = _hashSum;
    emit ConceroAutomation_EthersHashSumUpdated(_hashSum);
  }

  //////////////
  ///INTERNAL///
  //////////////
  /**
   * @notice Function to send a Request to Chainlink Functions
   * @param _args the arguments for the request as bytes array
   * @param _jsCode the JScode that will be executed.
   */
  function _sendRequest(bytes[] memory _args, string memory _jsCode) internal returns (bytes32) {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(_jsCode);
    req.addDONHostedSecrets(s_donHostedSecretsSlotId, s_donHostedSecretsVersion);
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
    PerformWithdrawRequest storage functionRequest = s_functionsRequests[requestId];
    address liquidityProvider = functionRequest.liquidityProvider;

    if (err.length > 0) {
      emit FunctionsRequestError(requestId);
      revert ConceroAutomation_CLFFallbackError(requestId);
      // todo: there is no fallback mechanism if CLF fails to trigger liquidity pull from child pools.
      // todo: if CLF fails, the LP will not be able to retry the withdrawal request.
    }

    s_withdrawTriggered[liquidityProvider] = false;
    uint256 requestsNumber = s_pendingWithdrawRequestsCLA.length;

    for (uint256 i; i < requestsNumber; ++i) {
      if (s_pendingWithdrawRequestsCLA[i] == liquidityProvider) {
        s_pendingWithdrawRequestsCLA[i] = s_pendingWithdrawRequestsCLA[s_pendingWithdrawRequestsCLA.length - 1];
        s_pendingWithdrawRequestsCLA.pop();
      }
    }
  }

  ///////////////////////////
  ///PURE & VIEW FUNCTIONS///
  ///////////////////////////
  function getPendingRequests() external view returns (address[] memory _requests) {
    _requests = s_pendingWithdrawRequestsCLA;
  }
  
  function getPendingWithdrawRequestsLength() public view returns (uint256) {
    return s_pendingWithdrawRequestsCLA.length;
  }
}
