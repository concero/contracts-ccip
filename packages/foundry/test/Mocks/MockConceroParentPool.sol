// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ConceroParentPool} from "contracts/ConceroParentPool.sol";

contract MockConceroParentPool is ConceroParentPool {
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
        address _owner
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
            _owner
        )
    {}

    /// @dev getter for returning withdraw request params
    function getWithdrawRequestParams(bytes32 _withdrawalRequestId)
        external
        view
        returns (address lpAddress, uint256 lpSupplySnapshot, uint256 lpAmountToBurn)
    {
        WithdrawRequest memory request = s_withdrawRequests[_withdrawalRequestId];
        lpAddress = request.lpAddress;
        lpSupplySnapshot = request.lpSupplySnapshot;
        lpAmountToBurn = request.lpAmountToBurn;
    }
}
