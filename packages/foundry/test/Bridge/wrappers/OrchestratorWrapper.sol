// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Orchestrator} from "contracts/Orchestrator.sol";

contract OrchestratorWrapper is Orchestrator {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _functionsRouter,
        address _dexSwap,
        address _concero,
        address _pool,
        address _proxy,
        uint8 _chainIndex,
        address[3] memory _messengers
    ) Orchestrator(_functionsRouter, _dexSwap, _concero, _pool, _proxy, _chainIndex, _messengers) {}

    // /*//////////////////////////////////////////////////////////////
    //                              GETTER
    // //////////////////////////////////////////////////////////////*/
    // function getLastCCIPFeeInLink(uint64 _dstChainSelector) external view returns (uint256) {
    //     return s_lastCCIPFeeInLink[_dstChainSelector];
    // }

    // function getBridgeTxIdsPerChain(
    //     uint64 _dstChainSelector
    // ) external view returns (bytes32[] memory) {
    //     return s_pendingCCIPTransactionsByDstChain[_dstChainSelector];
    // }
}
