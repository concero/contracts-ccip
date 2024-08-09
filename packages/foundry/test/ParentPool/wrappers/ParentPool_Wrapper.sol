// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

interface IParentPoolWrapper is IParentPool {
    function getDepositRequest(bytes32 requestId) external view returns (ConceroParentPool.DepositRequest memory);
    function getRequestType(bytes32 requestId) external view returns (ConceroParentPool.RequestType);
    function isMessenger(address _messenger) external view returns (bool);
    function getDepositsOnTheWayAmount() external view returns (uint256);
    function ccipReceive(Client.Any2EVMMessage calldata message) external;
    function getWithdrawRequestParams(bytes32 _withdrawalRequestId)
        external
        view
        returns (
            address lpAddress,
            uint256 lpSupplySnapshot,
            uint256 lpAmountToBurn,
            uint256 totalCrossChainLiquiditySnapshot,
            uint256 amountToWithdraw,
            uint256 liquidityRequestedFromEachPool,
            uint256 remainingLiquidityFromChildPools,
            uint256 triggeredAtTimestamp
        );
    function getDepositFeeAmount() external view returns (uint256);
    function getLoansInUse() external view returns (uint256);
    function getWithdrawalsOnTheWayAmount() external view returns (uint256);
    function getWithdrawRequest(bytes32 requestId) external view returns (ConceroParentPool.WithdrawRequest memory);
    function getNumberOfChildPools() external view returns (uint256);
}

contract ParentPool_Wrapper is ConceroParentPool {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _parentPoolProxy,
        address _link,
        bytes32 _donId,
        uint64 _subscriptionId,
        address _functionsRouter,
        address _ccipRouter,
        address _usdc,
        address _lpToken,
        address _orchestrator,
        address _owner,
        uint8 _slotId,
        address[3] memory _messengers
    )
        ConceroParentPool(
            _parentPoolProxy,
            _link,
            _donId,
            _subscriptionId,
            _functionsRouter,
            _ccipRouter,
            _usdc,
            _lpToken,
            _orchestrator,
            _owner,
            _slotId,
            _messengers
        )
    {}

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function getDepositRequest(bytes32 requestId) external view returns (ConceroParentPool.DepositRequest memory) {
        return s_depositRequests[requestId];
    }

    function getRequestType(bytes32 requestId) external view returns (ConceroParentPool.RequestType) {
        return s_clfRequestTypes[requestId];
    }

    function isMessenger(address _messenger) public view returns (bool) {
        return _isMessenger(_messenger);
    }

    function getDepositsOnTheWayAmount() external view returns (uint256) {
        return s_depositsOnTheWayAmount;
    }

    function getDepositFeeAmount() external view returns (uint256) {
        return s_depositFeeAmount;
    }

    function getLoansInUse() external view returns (uint256) {
        return s_loansInUse;
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/
    function getWithdrawRequest(bytes32 requestId) external view returns (ConceroParentPool.WithdrawRequest memory) {
        return s_withdrawRequests[requestId];
    }

    /// @dev getter for returning withdraw request params
    function getWithdrawRequestParams(bytes32 _withdrawalRequestId)
        external
        view
        returns (
            address lpAddress,
            uint256 lpSupplySnapshot,
            uint256 lpAmountToBurn,
            uint256 totalCrossChainLiquiditySnapshot,
            uint256 amountToWithdraw,
            uint256 liquidityRequestedFromEachPool,
            uint256 remainingLiquidityFromChildPools,
            uint256 triggeredAtTimestamp
        )
    {
        WithdrawRequest memory request = s_withdrawRequests[_withdrawalRequestId];
        lpAddress = request.lpAddress;
        lpSupplySnapshot = request.lpSupplySnapshot;
        lpAmountToBurn = request.lpAmountToBurn;
        totalCrossChainLiquiditySnapshot = request.totalCrossChainLiquiditySnapshot;
        amountToWithdraw = request.amountToWithdraw;
        liquidityRequestedFromEachPool = request.liquidityRequestedFromEachPool;
        remainingLiquidityFromChildPools = request.remainingLiquidityFromChildPools;
        triggeredAtTimestamp = request.triggeredAtTimestamp;
    }

    function getWithdrawalIdByClfRequestId(bytes32 _clfRequestId) external view returns (bytes32) {
        return s_withdrawalIdByCLFRequestId[_clfRequestId];
    }

    function getWithdrawalsOnTheWayAmount() external view returns (uint256) {
        return s_withdrawalsOnTheWayAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 POOLS
    //////////////////////////////////////////////////////////////*/
    function getNumberOfChildPools() external view returns (uint256) {
        return s_poolChainSelectors.length;
    }
}
