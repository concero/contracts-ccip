// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ParentPoolStorage} from "./Libraries/ParentPoolStorage.sol";
import {IParentPoolCCIP} from "./Interfaces/IParentPoolCCIP.sol";
import {IParentPoolViewViaDelegate} from "./Interfaces/IParentPoolViewViaDelegate.sol";

error ConceroParentPoolOrchestrator_UnableToCompleteDelegateCall(bytes data);

contract ConceroParentPoolOrchestrator is ParentPoolStorage {
    ///////////////
    ///IMMUTABLE///
    ///////////////

    address internal immutable i_parentPoolCLF;
    address internal immutable i_parentPoolCLA;
    address internal immutable i_parentPoolCCIP;
    address internal immutable i_parentPoolProxy;

    constructor(
        address _parentPoolCLF,
        address _parentPoolCLA,
        address _parentPoolCCIP,
        address _parentPoolProxy
    ) {
        i_parentPoolProxy = _parentPoolProxy;
        i_parentPoolCLF = _parentPoolCLF;
        i_parentPoolCLA = _parentPoolCLA;
        i_parentPoolCCIP = _parentPoolCCIP;
    }

    receive() external payable {}

    ////////////////////////
    /////VIEW FUNCTIONS/////
    ////////////////////////

    function delegateCallWrapper(bytes memory data, address target) internal returns (uint256) {
        (bool success, bytes memory data) = target.delegatecall(data);

        if (!success) {
            revert ConceroParentPoolOrchestrator_UnableToCompleteDelegateCall(data);
        }
        return data;
    }

    function calculateLpAmount(
        uint256 childPoolsBalance,
        uint256 amountToDeposit
    ) external view returns (uint256) {
        bytes memory data = abi.encodeWithSelector(
            IParentPoolCCIP.calculateLpAmount.selector,
            childPoolsBalance,
            amountToDeposit
        );

        return
            IParentPoolViewViaDelegate(address(this)).calculateLpAmountViaDelegate(
                data,
                i_parentPoolCCIP
            );
    }
}
