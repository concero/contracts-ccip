// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

interface IParentPoolWrapper is IParentPool {
    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ConceroParentPool.DepositRequest memory);
    function getRequestType(
        bytes32 requestId
    ) external view returns (ConceroParentPool.RequestType);
    function isMessenger(address _messenger) external view returns (bool);
    function getDepositsOnTheWayAmount() external view returns (uint256);
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
        address _automation,
        address _orchestrator,
        address _owner,
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
            _automation,
            _orchestrator,
            _owner,
            _messengers
        )
    {}

    /*//////////////////////////////////////////////////////////////
                                DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ConceroParentPool.DepositRequest memory) {
        return s_depositRequests[requestId];
    }

    function getRequestType(
        bytes32 requestId
    ) external view returns (ConceroParentPool.RequestType) {
        return s_clfRequestTypes[requestId];
    }

    function isMessenger(address _messenger) public view returns (bool) {
        return _isMessenger(_messenger);
    }

    function getDepositsOnTheWayAmount() external view returns (uint256) {
        return s_depositsOnTheWayAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                WITHDRAW
    //////////////////////////////////////////////////////////////*/
    /// @dev getter for returning withdraw request params
    function getWithdrawRequestParams(
        bytes32 _withdrawalRequestId
    )
        external
        view
        returns (
            address lpAddress,
            uint256 lpSupplySnapshot,
            uint256 lpAmountToBurn,
            uint256 amountToWithdraw
        )
    {
        WithdrawRequest memory request = s_withdrawRequests[_withdrawalRequestId];
        lpAddress = request.lpAddress;
        lpSupplySnapshot = request.lpSupplySnapshot;
        lpAmountToBurn = request.lpAmountToBurn;
        amountToWithdraw = request.amountToWithdraw;
    }
}
