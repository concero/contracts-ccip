// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ParentPool} from "contracts/ParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

interface IDepositParentPool is IParentPool {
    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ParentPool.DepositRequest memory);

    function getRequestType(bytes32 requestId) external view returns (ParentPool.CLFRequestType);

    function isMessenger(address _messenger) external view returns (bool);
}

contract ParentPoolDepositWrapper is ParentPool {
    constructor(
        address _parentPoolProxy,
        address _parentPoolCLFCLA,
        address _automationForwarder,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _lpToken,
        address _infraProxy,
        address _clfRouter,
        address _owner,
        address[3] memory _messengers
    )
        ParentPool(
            _parentPoolProxy,
            _parentPoolCLFCLA,
            _automationForwarder,
            _link,
            _ccipRouter,
            _usdc,
            _lpToken,
            _infraProxy,
            _clfRouter,
            _owner,
            _messengers
        )
    {}

    function getDepositRequest(
        bytes32 requestId
    ) external view returns (ParentPool.DepositRequest memory) {
        return s_depositRequests[requestId];
    }

    function getRequestType(bytes32 requestId) external view returns (ParentPool.CLFRequestType) {
        return s_clfRequestTypes[requestId];
    }

    function isMessenger(address _messenger) public view returns (bool) {
        return _isMessenger(_messenger);
    }
}
