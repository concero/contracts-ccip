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
    //////////////
    /// EVENTS ///
    //////////////

    event CLFRequestError(bytes32 requestId, IParentPool.RequestType requestType, bytes err);
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
            if (requestType == RequestType.startDeposit_getChildPoolsLiquidity) {
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
}
