// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IDexSwap} from "./IDexSwap.sol";
import {IInfraStorage} from "./IInfraStorage.sol";

interface IInfraOrchestrator {
    struct Integration {
        address integrator;
        uint256 feeBps;
    }

    event IntegratorFeesCollected(address indexed integrator, address token, uint256 amount);
    event IntegratorFeesWithdrawn(address indexed integrator, address token, uint256 amount);

    function isTxConfirmed(bytes32 _txId) external view returns (bool);
}

interface IOrchestratorViewDelegate {
    function getSrcTotalFeeInUSDCViaDelegateCall(
        IInfraStorage.CCIPToken tokenType,
        uint64 dstChainSelector,
        uint256 amount
    ) external view returns (uint256);
}
