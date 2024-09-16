// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity ^0.8.0;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {ParentPoolStorage} from "./Libraries/ParentPoolStorage.sol";
import {ParentPoolCommon} from "./ParentPoolCommon.sol";

contract ParentPoolCLFCLA is
    FunctionsClient,
    AutomationCompatible,
    ParentPoolCommon,
    ParentPoolStorage
{
    ///////////////
    ///CONSTANTS///
    ///////////////

    ///@notice JS Code for Chainlink Functions
    // TODO: add automation js code to this contract
    string internal constant JS_CODE =
        "try { const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js'; const q = 'https://raw.githubusercontent.com/concero/contracts-ccip/' + 'release' + `/packages/hardhat/tasks/CLFScripts/dist/pool/${bytesArgs[2] === '0x1' ? 'distributeLiquidity' : 'getTotalBalance'}.min.js`; const [t, p] = await Promise.all([fetch(u), fetch(q)]); const [e, c] = await Promise.all([t.text(), p.text()]); const g = async s => { return ( '0x' + Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))) .map(v => ('0' + v.toString(16)).slice(-2).toLowerCase()) .join('') ); }; const r = await g(c); const x = await g(e); const b = bytesArgs[0].toLowerCase(); const o = bytesArgs[1].toLowerCase(); if (r === b && x === o) { const ethers = new Function(e + '; return ethers;')(); return await eval(c); } throw new Error(`${r}!=${b}||${x}!=${o}`); } catch (e) { throw new Error(e.message.slice(0, 255));}";
    uint32 public constant CL_FUNCTIONS_CALLBACK_GAS_LIMIT = 2_000_000;

    /////////////////
    ////IMMUTABLES///
    /////////////////

    address internal immutable i_automationForwarder;
    ///@notice Chainlink Function Don ID
    bytes32 private immutable i_donId;
    uint64 private immutable i_subscriptionId;

    //////////////
    /// EVENTS ///
    //////////////

    event CLFRequestError(bytes32 requestId, IParentPool.RequestType requestType, bytes err);

    constructor(
        address parentPoolProxy,
        address lpToken,
        address msg0,
        address msg1,
        address msg2
    ) ParentPoolCommon(parentPoolProxy, lpToken, msg0, msg1, msg2) {}

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
        IParentPool.RequestType requestType = s_clfRequestTypes[requestId];

        if (err.length > 0) {
            if (requestType == IParentPool.RequestType.startDeposit_getChildPoolsLiquidity) {
                delete s_depositRequests[requestId];
            } else if (
                requestType == IParentPool.RequestType.startWithdrawal_getChildPoolsLiquidity
            ) {
                bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
                address lpAddress = s_withdrawRequests[withdrawalId].lpAddress;
                uint256 lpAmountToBurn = s_withdrawRequests[withdrawalId].lpAmountToBurn;

                IERC20(i_lpToken).safeTransfer(lpAddress, lpAmountToBurn);

                delete s_withdrawRequests[withdrawalId];
                delete s_withdrawalIdByLPAddress[lpAddress];
                delete s_withdrawalIdByCLFRequestId[requestId];
            }

            emit CLFRequestError(requestId, requestType, err);
        } else {
            if (requestType == IParentPool.RequestType.startDeposit_getChildPoolsLiquidity) {
                _handleStartDepositCLFFulfill(requestId, response);
            } else if (requestType == RequestType.startWithdrawal_getChildPoolsLiquidity) {
                _handleStartWithdrawalCLFFulfill(requestId, response);
                delete s_withdrawalIdByCLFRequestId[requestId];
            } else if (requestType == RequestType.performUpkeep_requestLiquidityTransfer) {
                _handleAutomationCLFFulfill(requestId, response);
            }
        }

        delete s_clfRequestTypes[requestId];
    }

    function sendCLFRequest(
        IParentPool.RequestType requestType,
        bytes memory args,
        uint256 gasLimit
    ) external onlyProxyContext {}

    ///////////////
    /// INTERNAL ///
    ///////////////

    function _handleStartDepositCLFFulfill(bytes32 requestId, bytes memory response) internal {
        DepositRequest storage request = s_depositRequests[requestId];

        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        request.childPoolsLiquiditySnapshot = childPoolsLiquidity;

        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    function _handleStartWithdrawalCLFFulfill(bytes32 requestId, bytes memory response) internal {
        (
            uint256 childPoolsLiquidity,
            bytes1[] memory depositsOnTheWayIdsToDelete
        ) = _decodeCLFResponse(response);

        bytes32 withdrawalId = s_withdrawalIdByCLFRequestId[requestId];
        WithdrawRequest storage request = s_withdrawRequests[withdrawalId];

        _updateWithdrawalRequest(request, withdrawalId, childPoolsLiquidity);
        _deleteDepositsOnTheWayByIndexes(depositsOnTheWayIdsToDelete);
    }

    function _decodeCLFResponse(
        bytes memory response
    ) internal pure returns (uint256, bytes1[] memory) {
        uint256 totalBalance;
        assembly {
            totalBalance := mload(add(response, 32))
        }

        if (response.length == 32) {
            return (totalBalance, new bytes1[](0));
        } else {
            bytes1[] memory depositsOnTheWayIdsToDelete = new bytes1[](response.length - 32);
            for (uint256 i = 32; i < response.length; i++) {
                depositsOnTheWayIdsToDelete[i - 32] = response[i];
            }

            return (totalBalance, depositsOnTheWayIdsToDelete);
        }
    }

    function _deleteDepositsOnTheWayByIndexes(
        bytes1[] memory _depositsOnTheWayIndexesToDelete
    ) internal {
        uint256 depositsOnTheWayIndexesToDeleteLength = _depositsOnTheWayIndexesToDelete.length;

        if (depositsOnTheWayIndexesToDeleteLength == 0) {
            return;
        }

        uint256 s_depositsOnTheWayArrayLength = s_depositsOnTheWayArray.length;

        for (uint256 i; i < depositsOnTheWayIndexesToDeleteLength; i++) {
            uint8 indexToDelete = uint8(_depositsOnTheWayIndexesToDelete[i]);

            if (indexToDelete >= s_depositsOnTheWayArrayLength) {
                continue;
            }

            s_depositsOnTheWayAmount -= s_depositsOnTheWayArray[indexToDelete].amount;
            delete s_depositsOnTheWayArray[indexToDelete];
        }
    }

    /**
     * @notice Function to update cross-chain rewards which will be paid to liquidity providers in the end of
     * withdraw period.
     * @param _withdrawalRequest - pointer to the WithdrawRequest struct
     * @param _childPoolsLiquidity The total liquidity of all child pools
     * @dev This function must be called only by an allowed Messenger & must not revert
     * @dev _totalUSDCCrossChainBalance MUST have 10**6 decimals.
     */
    function _updateWithdrawalRequest(
        WithdrawRequest storage _withdrawalRequest,
        bytes32 _withdrawalId,
        uint256 _childPoolsLiquidity
    ) private {
        uint256 lpToBurn = _withdrawalRequest.lpAmountToBurn;
        uint256 lpSupplySnapshot = _withdrawalRequest.lpSupplySnapshot;
        uint256 childPoolsCount = s_poolChainSelectors.length;

        uint256 amountToWithdrawWithUsdcDecimals = _calculateWithdrawableAmount(
            _childPoolsLiquidity,
            lpToBurn,
            lpSupplySnapshot
        );
        uint256 withdrawalPortionPerPool = amountToWithdrawWithUsdcDecimals / (childPoolsCount + 1);

        _withdrawalRequest.amountToWithdraw = amountToWithdrawWithUsdcDecimals;
        _withdrawalRequest.liquidityRequestedFromEachPool = withdrawalPortionPerPool;
        _withdrawalRequest.remainingLiquidityFromChildPools =
            amountToWithdrawWithUsdcDecimals -
            withdrawalPortionPerPool;
        _withdrawalRequest.triggeredAtTimestamp = block.timestamp + WITHDRAW_DEADLINE_SECONDS;

        _addPendingWithdrawalId(_withdrawalId);
        emit ConceroParentPool_RequestUpdated(_withdrawalId);
    }

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
}
