// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";

contract AddDepositOnTheWayRequestTest is ConceroParentPool, Test {
    constructor()
        ConceroParentPool(
            address(0),
            address(vm.envAddress("LINK_BASE")),
            bytes32(0),
            0,
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(vm.envAddress("LPTOKEN_BASE")),
            address(vm.envAddress("CONCERO_AUTOMATION_BASE")),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(msg.sender)
        )
    {}

    function testDepositOnTheWayIdsOverflow() public {
        for (uint256 i = 0; i < MAX_DEPOSIT_REQUESTS_COUNT + 2; i++) {
            _addDepositOnTheWayRequest(bytes32(0), 0, 100);
        }

        _deleteDepositOnTheWayRequestByIndex(4);

        DepositOnTheWay memory lastDepositOnTheWay = s_depositsOnTheWayArray[
            s_depositsOnTheWayArray.length - 1
        ];

        console.log("lastDepositOnTheWay: %s", lastDepositOnTheWay.id);
    }

    function _deleteDepositOnTheWayRequestByIndex(uint256 index) private {
        s_depositsOnTheWayArray[index] = s_depositsOnTheWayArray[
            s_depositsOnTheWayArray.length - 1
        ];
        s_depositsOnTheWayArray.pop();
    }
}
