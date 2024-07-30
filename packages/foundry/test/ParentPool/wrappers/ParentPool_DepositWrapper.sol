// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

interface IDepositParentPool is IParentPool {
    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ConceroParentPool.DepositRequest memory);

    function getRequestType(
        bytes32 requestId
    ) external view returns (ConceroParentPool.RequestType);

    function isMessenger(address _messenger) external view returns (bool);
}

contract ParentPool_DepositWrapper is ConceroParentPool {
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
        address[3] memory _msgrs
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
            _msgrs
        )
    {}

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
}
