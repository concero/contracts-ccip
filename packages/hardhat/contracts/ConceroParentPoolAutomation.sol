//// SPDX-License-Identifier: UNLICENSED
///**
// * @title Security Reporting
// * @notice If you discover any security vulnerabilities, please report them responsibly.
// * @contact email: security@concero.io
// */
//pragma solidity 0.8.20;
//
//import {ParentPoolStorage} from "./Libraries/ParentPoolStorage.sol";
//
//contract ConceroParentPoolAutomation is IParentPool, ParentPoolStorage {
//    /*//////////////////////////////////////////////////////////////
//						     EXTERNAL
//   //////////////////////////////////////////////////////////////*/
//
//    /**
//     * @notice Chainlink Automation Function to check for requests with fulfilled conditions
//     * We don't use the calldata
//     * @return _upkeepNeeded it will return true, if the time condition is reached
//     * @return _performData the payload we need to send through performUpkeep to Chainlink functions.
//     * @dev this function must only be simulated offchain by Chainlink Automation nodes
//     */
//    function checkUpkeep(
//        bytes calldata /* checkData */
//    ) external view override cannotExecute returns (bool, bytes memory) {
//        uint256 withdrawalRequestsCount = s_withdrawalRequestIds.length;
//
//        for (uint256 i; i < withdrawalRequestsCount; ++i) {
//            bytes32 withdrawalId = s_withdrawalRequestIds[i];
//
//            WithdrawRequest memory withdrawalRequest = _getWithdrawalRequestById(withdrawalId);
//
//            address lpAddress = withdrawalRequest.lpAddress;
//            uint256 amountToWithdraw = withdrawalRequest.amountToWithdraw;
//            uint256 liquidityRequestedFromEachPool = withdrawalRequest
//                .liquidityRequestedFromEachPool;
//
//            if (amountToWithdraw == 0) {
//                continue;
//            }
//            // s_withdrawTriggered is used to prevent multiple CLA triggers of the same withdrawal request
//            if (
//                s_withdrawTriggered[withdrawalId] == false &&
//                block.timestamp > withdrawalRequest.triggeredAtTimestamp
//            ) {
//                bytes memory _performData = abi.encode(
//                    lpAddress,
//                    liquidityRequestedFromEachPool,
//                    withdrawalId
//                );
//                bool _upkeepNeeded = true;
//                return (_upkeepNeeded, _performData);
//            }
//        }
//        return (false, "");
//    }
//
//    /**
//     * @notice Chainlink Automation function that will perform storage update and call Chainlink Functions
//     * @param _performData the performData encoded in checkUpkeep function
//     * @dev this function must be called only by the Chainlink Forwarder unique address
//     */
//    function performUpkeep(bytes calldata _performData) external override {
//        if (msg.sender != i_automationForwarder)
//            revert ConceroParentPool_CallerNotAllowed(msg.sender);
//        (address lpAddress, uint256 liquidityRequestedFromEachPool, bytes32 withdrawalId) = abi
//            .decode(_performData, (address, uint256, bytes32));
//
//        if (s_withdrawTriggered[withdrawalId] == true) {
//            revert ConceroParentPool_WithdrawAlreadyTriggered(withdrawalId);
//        } else {
//            s_withdrawTriggered[withdrawalId] = true;
//        }
//
//        bytes[] memory args = new bytes[](5);
//        args[0] = abi.encodePacked(s_hashSum);
//        args[1] = abi.encodePacked(s_ethersHashSum);
//        args[2] = abi.encodePacked(lpAddress);
//        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
//        args[4] = abi.encodePacked(withdrawalId);
//
//        bytes32 reqId = _sendRequest(args, JS_CODE);
//        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;
//        s_clfRequestTypes[reqId] = RequestType.performUpkeep_requestLiquidityTransfer;
//
//        _addWithdrawalOnTheWayAmountById(withdrawalId);
//        emit ConceroParentPool_UpkeepPerformed(reqId);
//    }
//
//    function retryPerformWithdrawalRequest() external {
//        bytes32 withdrawalId = s_withdrawalIdByLPAddress[msg.sender];
//        WithdrawRequest memory withdrawalRequest = _getWithdrawalRequestById(withdrawalId);
//
//        uint256 amountToWithdraw = withdrawalRequest.amountToWithdraw;
//        address lpAddress = withdrawalRequest.lpAddress;
//        uint256 liquidityRequestedFromEachPool = withdrawalRequest.liquidityRequestedFromEachPool;
//        uint256 triggeredAtTimestamp = withdrawalRequest.triggeredAtTimestamp;
//
//        if (msg.sender != lpAddress) revert ConceroParentPool_CallerNotAllowed(msg.sender);
//
//        if (amountToWithdraw == 0) {
//            revert ConceroParentPool_WithdrawRequestDoesntExist(withdrawalId);
//        }
//
//        if (block.timestamp < triggeredAtTimestamp + 30 minutes) {
//            revert ConceroParentPool_WithdrawRequestNotReady(withdrawalId);
//        }
//
//        bytes[] memory args = new bytes[](5);
//        args[0] = abi.encodePacked(s_hashSum);
//        args[1] = abi.encodePacked(s_ethersHashSum);
//        args[2] = abi.encodePacked(lpAddress);
//        args[3] = abi.encodePacked(liquidityRequestedFromEachPool);
//        args[4] = abi.encodePacked(withdrawalId);
//
//        bytes32 reqId = _sendRequest(args, JS_CODE);
//        s_withdrawalIdByCLFRequestId[reqId] = withdrawalId;
//
//        emit ConceroParentPool_RetryPerformed(reqId);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//							INTERNAL
//	  //////////////////////////////////////////////////////////////*/
//
//    /**
//     * @notice Function to add new withdraw request to CLA monitoring system
//     * @param _withdrawalId the ID of the withdrawal request
//     * @dev this function should only be called by the ConceroPool.sol
//     */
//    function _addPendingWithdrawalId(bytes32 _withdrawalId) internal {
//        s_withdrawalRequestIds.push(_withdrawalId);
//        emit ConceroParentPool_RequestAdded(_withdrawalId);
//    }
//}
