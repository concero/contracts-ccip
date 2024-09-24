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

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    function setLastCCIPFeeInLink(uint64 _dstChainSelector, uint256 _lastFeeInLink) external {
        s_lastCCIPFeeInLink[_dstChainSelector] = _lastFeeInLink;
    }

    function setLastGasPrices(uint64 _chainSelector, uint256 _lastGasPrice) external {
        s_lastGasPrices[_chainSelector] = _lastGasPrice;
    }

    function setLatestNativeUsdcRate(uint256 _latestRate) external {
        s_latestNativeUsdcRate = _latestRate;
    }

    function setLatestLinkUsdcRate(uint256 _latestRate) external {
        s_latestLinkUsdcRate = _latestRate;
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getLastCCIPFeeInLink(uint64 _dstChainSelector) external view returns (uint256) {
        return s_lastCCIPFeeInLink[_dstChainSelector];
    }

    function getBridgeTxIdsPerChain(
        uint64 _dstChainSelector
    ) external view returns (bytes32[] memory) {
        return s_pendingSettlementTxsByDstChain[_dstChainSelector];
    }

    function getFunctionsFeeInUsdcDelegateCall(
        uint64 _dstChainSelector
    ) external returns (uint256) {
        (bool success, bytes memory returnData) = i_concero.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("getFunctionsFeeInUsdc(uint64)")),
                _dstChainSelector
            )
        );
        require(success, "getFunctionsFeeInUsdc delegate call failed");
        uint256 functionsFeeInUsdc = abi.decode(returnData, (uint256));
        return functionsFeeInUsdc;
    }

    function getCcipFeeInUsdcDelegateCall(uint64 _dstChainSelector) external returns (uint256) {
        (bool success, bytes memory returnData) = i_concero.delegatecall(
            abi.encodeWithSignature("getCCIPFeeInUsdc(uint64)", _dstChainSelector)
        );
        require(success, "getCCIPFeeInUsdc delegate call failed");
        uint256 ccipFeeInUsdc = abi.decode(returnData, (uint256));
        return ccipFeeInUsdc;
    }

    function getSrcTotalFeeInUSDCDelegateCall(
        uint64 _dstChainSelector,
        uint256 _amount
    ) external returns (uint256) {
        (bool success, bytes memory returnData) = i_concero.delegatecall(
            abi.encodeWithSelector(
                bytes4(keccak256("getSrcTotalFeeInUSDC(uint64,uint256)")),
                _dstChainSelector,
                _amount
            )
        );
        require(success, "getSrcTotalFeeInUSDC delegate call failed");
        uint256 srcTotalFeeInUsdc = abi.decode(returnData, (uint256));
        return srcTotalFeeInUsdc;
    }
}
