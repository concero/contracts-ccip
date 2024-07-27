// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ForkType, CreateAndSwitchToForkTest} from "../../utils/CreateAndSwitchToFork.t.sol";

contract AddDepositOnTheWayRequestTest is ConceroParentPool, CreateAndSwitchToForkTest {
    uint256 private baseFork;

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

    function setUp() public {
        switchToFork(ForkType.BASE);
    }

    function test() public {
        _fillDepositsRequestArray();

        _deleteDepositOnTheWayRequestByIndex(4);
        _addDepositOnTheWayRequest(bytes32(0), 0, 100);

        DepositOnTheWay memory lastDepositOnTheWay = s_depositsOnTheWayArray[
            s_depositsOnTheWayArray.length - 1
        ];

        uint8 expectedLastDepositId = 5;
        assert(lastDepositOnTheWay.id == expectedLastDepositId);
    }

    function _fillDepositsRequestArray() private {
        for (uint256 i = 0; i <= MAX_DEPOSIT_REQUESTS_COUNT; i++) {
            _addDepositOnTheWayRequest(bytes32(0), 0, 100);
        }
    }

    function _deleteDepositOnTheWayRequestByIndex(uint256 index) private {
        s_depositsOnTheWayArray[index] = s_depositsOnTheWayArray[
            s_depositsOnTheWayArray.length - 1
        ];
        s_depositsOnTheWayArray.pop();
    }
}
