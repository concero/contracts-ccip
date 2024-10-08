// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IInfraStorage} from "./IInfraStorage.sol";

interface IInfraCLF is IInfraStorage {
    function fulfillRequestWrapper(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) external;

    function addUnconfirmedTX(
        bytes32 ccipMessageId,
        address sender,
        address recipient,
        uint256 amount,
        uint64 srcChainSelector,
        CCIPToken token,
        uint256 blockNumber,
        bytes calldata dstSwapData
    ) external;
}
