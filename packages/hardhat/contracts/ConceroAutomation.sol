// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {IParentPool} from "./Interfaces/IParentPool.sol";
import {IConceroAutomation} from "./Interfaces/IConceroAutomation.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
///@notice error emitted when the caller is not the owner.
error ConceroAutomation_CallerNotAllowed(address caller);
error ConceroAutomation_WithdrawAlreadyTriggered(bytes32 withdrawalId);
error ConceroAutomation__WithdrawRequestDoesntExist(bytes32 withdrawalId);
error ConceroAutomation__WithdrawRequestNotReady(bytes32 withdrawalId);
contract ConceroAutomation is IConceroAutomation, AutomationCompatible, FunctionsClient, Ownable {
    ///////////////////////
    ///TYPE DECLARATIONS///
    ///////////////////////
    using FunctionsRequest for FunctionsRequest.Request;

    struct PerformWithdrawRequest {
        address liquidityProvider;
        uint256 amount;
        bytes32 withdrawId;
        bool failed;
    }

    ///////////////////////////////////////////////////////////
    //////////////////////// VARIABLES ////////////////////////
    ///////////////////////////////////////////////////////////
    ///////////////
    ///CONSTANTS///
    ///////////////
    ///@notice Chainlink Functions Gas Limit
    uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 2_000_000;
    ///@notice JS Code for Chainlink Functions
    string internal constant JS_CODE =
        "try { const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js'; const q = 'https://raw.githubusercontent.com/concero/contracts-ccip/' + 'release' + '/packages/hardhat/tasks/CLFScripts/dist/pool/collectLiquidity.min.js'; const [t, p] = await Promise.all([fetch(u), fetch(q)]); const [e, c] = await Promise.all([t.text(), p.text()]); const g = async s => { return ( '0x' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))) .map(v => ('0' + v.toString(16)).slice(-2).toLowerCase()) .join('') ); }; const r = await g(c); const x = await g(e); const b = bytesArgs[0].toLowerCase(); const o = bytesArgs[1].toLowerCase(); if (r === b && x === o) { const ethers = new Function(e + '; return ethers;')(); return await eval(c); } throw new Error(`${r}!=${b}||${x}!=${o}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";

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
    bytes32[] public s_withdrawalRequestIds;

    ///@notice Mapping to keep track of Chainlink Functions requests
    mapping(bytes32 withdrawalId => bool isTriggered) public s_withdrawTriggered;
    mapping(bytes32 clfReqId => bytes32 withdrawalId) public s_withdrawalIdByCLFRequestId;
    ////////////////////////////////////////////////////////
    //////////////////////// EVENTS ////////////////////////
    ////////////////////////////////////////////////////////
    ///@notice event emitted when a new request is added
    event ConceroAutomation_RequestAdded(bytes32 requestId);
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
    ///@notice event emitted when the Don Slot ID is updated
    event ConceroAutomation_DonHostedSlotId(uint8 slotId);
    ///@notice event emitted when the hashSum of Chainlink Function is updated
    event ConceroAutomation_HashSumUpdated(bytes32 hashSum);
    ///@notice event emitted when the Ethers HashSum is updated
    event ConceroAutomation_EthersHashSumUpdated(bytes32 hashSum);
    ///@notice event emitted when a LP retries a withdrawal request
    event ConceroAutomation_RetryPerformed(bytes32 reqId);

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

    function setDonHostedSecretsSlotId(uint8 _slotId) external onlyOwner {
        s_donHostedSecretsSlotId = _slotId;

        emit ConceroAutomation_DonHostedSlotId(_slotId);
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

    /**
     * @notice Function to add new withdraw request to CLA monitoring system
     * @param _withdrawalId the ID of the withdrawal request
     * @dev this function should only be called by the ConceroPool.sol
     */
    function addPendingWithdrawalId(bytes32 _withdrawalId) external {
        if (msg.sender != i_masterPoolProxy) revert ConceroAutomation_CallerNotAllowed(msg.sender);
        s_withdrawalRequestIds.push(_withdrawalId);
        emit ConceroAutomation_RequestAdded(_withdrawalId);
    }

    /**
     * @notice Chainlink Automation Function to check for requests with fulfilled conditions
     * We don't use the calldata
     * @return _upkeepNeeded it will return true, if the time condition is reached
     * @return _performData the payload we need to send through performUpkeep to Chainlink functions.
     * @dev this function must be called only by the Chainlink Forwarder unique address
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override cannotExecute returns (bool, bytes memory) {
        uint256 withdrawalRequestsCount = s_withdrawalRequestIds.length;

        for (uint256 i; i < withdrawalRequestsCount; ++i) {
            bytes32 withdrawalId = s_withdrawalRequestIds[i];

            IParentPool.WithdrawRequest memory withdrawalRequest = IParentPool(i_masterPoolProxy)
                .getWithdrawalRequestById(withdrawalId);

            address lpAddress = withdrawalRequest.lpAddress;
            uint256 amountToWithdraw = withdrawalRequest.amountToWithdraw;
            uint256 liquidityRequestedFromEachPool = withdrawalRequest
                .liquidityRequestedFromEachPool;

            if (amountToWithdraw == 0) {
                continue;
            }
            // s_withdrawTriggered is used to prevent multiple CLA triggers of the same withdrawal request
            if (
                s_withdrawTriggered[withdrawalId] == false &&
                block.timestamp > withdrawalRequest.triggeredAtTimestamp
            ) {
                bytes memory _performData = abi.encode(
                    lpAddress,
                    liquidityRequestedFromEachPool,
                    withdrawalId
                );
                bool _upkeepNeeded = true;
                return (_upkeepNeeded, _performData);
            }
        }
        return (false, "");
    }

    /**
     * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
     * @param _performData the performData encoded in checkUpkeep function
     * @dev this function must be called only by the Chainlink Forwarder unique address
     */
    function performUpkeep(bytes calldata _performData) external override {
        if (msg.sender != s_forwarderAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);
        (address lpAddress, uint256 liquidityRequestedFromEachPool, bytes32 withdrawalId) = abi
            .decode(_performData, (address, uint256, bytes32));

        if (s_withdrawTriggered[withdrawalId] == true) {
            revert ConceroAutomation_WithdrawAlreadyTriggered(withdrawalId);
        } else {
            s_withdrawTriggered[withdrawalId] = true;
        }

        bytes[] memory args = new bytes[](5);
        args[0] = abi.encodePacked(s_hashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(lpAddress);
        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
        args[4] = abi.encodePacked(withdrawalId);

        bytes32 reqId = _sendRequest(args, JS_CODE);
        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;

        IParentPool(i_masterPoolProxy).addWithdrawalOnTheWayAmountById(withdrawalId);
        emit ConceroAutomation_UpkeepPerformed(reqId);
    }

    function retryPerformWithdrawalRequest(bytes32 _withdrawalId) external {
        IParentPool.WithdrawRequest memory withdrawalRequest = IParentPool(i_masterPoolProxy)
            .getWithdrawalRequestById(_withdrawalId);

        uint256 amountToWithdraw = withdrawalRequest.amountToWithdraw;
        address lpAddress = withdrawalRequest.lpAddress;
        uint256 liquidityRequestedFromEachPool = withdrawalRequest.liquidityRequestedFromEachPool;
        uint256 triggeredAtTimestamp = withdrawalRequest.triggeredAtTimestamp;

        if (msg.sender != lpAddress) revert ConceroAutomation_CallerNotAllowed(msg.sender);

        if (amountToWithdraw == 0) {
            revert ConceroAutomation__WithdrawRequestDoesntExist(_withdrawalId);
        }

        if (block.timestamp < triggeredAtTimestamp + 30 minutes) {
            revert ConceroAutomation__WithdrawRequestNotReady(_withdrawalId);
        }

        bytes[] memory args = new bytes[](5);
        args[0] = abi.encodePacked(s_hashSum);
        args[1] = abi.encodePacked(s_ethersHashSum);
        args[2] = abi.encodePacked(lpAddress);
        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
        args[4] = abi.encodePacked(_withdrawalId);

        bytes32 reqId = _sendRequest(args, JS_CODE);
        s_withdrawalIdByCLFRequestId[reqId] = _withdrawalId;

        emit ConceroAutomation_RetryPerformed(reqId);
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
        return
            _sendRequest(
                req.encodeCBOR(),
                i_subscriptionId,
                CL_FUNCTIONS_CALLBACK_GAS_LIMIT,
                i_donId
            );
    }

    /**
     * @notice Chainlink Functions fallback function
     * @param requestId the ID of the request sent
     * @param response the response of the request sent
     * @param err the error of the request sent
     * @dev response & err will never be empty or populated at same time.
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];

        if (err.length > 0) {
            emit FunctionsRequestError(requestId);
            return;
        }

        uint256 withdrawalRequestsCount = s_withdrawalRequestIds.length;

        for (uint256 i; i < withdrawalRequestsCount; ++i) {
            if (s_withdrawalRequestIds[i] == withdrawalId) {
                s_withdrawalRequestIds[i] = s_withdrawalRequestIds[
                    s_withdrawalRequestIds.length - 1
                ];
                s_withdrawalRequestIds.pop();
            }
        }
    }

    ///////////////////////////
    ///PURE & VIEW FUNCTIONS///
    ///////////////////////////
    function getPendingRequests() external view returns (bytes32[] memory _requests) {
        _requests = s_withdrawalRequestIds;
    }

    function getPendingWithdrawRequestsLength() public view returns (uint256) {
        return s_withdrawalRequestIds.length;
    }
}
