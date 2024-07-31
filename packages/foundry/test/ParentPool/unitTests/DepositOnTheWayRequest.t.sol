// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ForkType, CreateAndSwitchToForkTest} from "../../utils/CreateAndSwitchToFork.t.sol";

contract DepositOnTheWayRequest is ConceroParentPool, CreateAndSwitchToForkTest {
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
            address(msg.sender),
            [vm.envAddress("MESSENGER_0_ADDRESS"), address(0), address(0)]
        )
    {}

    function setUp() public {}

    function test_AddDepositOnTheWay() public {
        _fillDepositsRequestArray(MAX_DEPOSIT_REQUESTS_COUNT);
        console.log(s_depositsOnTheWayArray.length);
        _deleteDepositOnTheWayRequestByIndex(4);
        _addDepositOnTheWayRequest(bytes32(0), 0, 100);

        DepositOnTheWay memory lastDepositOnTheWay = s_depositsOnTheWayArray[
            s_depositsOnTheWayArray.length - 1
        ];

        uint8 expectedLastDepositId = 5;
        assert(lastDepositOnTheWay.id == expectedLastDepositId);
    }

    function test_UpdateDepositsOnTheWay() public {
        uint8[] memory depositsOnTheWayStatuses = new uint8[](3);

        uint256 maxDepositsRequestsCount = MAX_DEPOSIT_REQUESTS_COUNT / 2 - 15;

        _fillDepositsRequestArray(maxDepositsRequestsCount);

        depositsOnTheWayStatuses[0] = 1;
        depositsOnTheWayStatuses[1] = 5;
        depositsOnTheWayStatuses[2] = 3;

        uint256 gasBefore = gasleft();
        _deleteDepositsOnTheWayByIds(depositsOnTheWayStatuses);
        uint256 gasAfter = gasleft();

        uint256 gasUsed = gasBefore - gasAfter;
        console.log("gasUsed: ", gasUsed);

        assert(gasUsed < 200_000);
    }

    function test_bytesToUint8Array() public {
        bytes1 b1 = bytes1(uint8(5));
        bytes1 b2 = bytes1(uint8(0));
        bytes memory b = new bytes(2);
        b[0] = b1;
        b[1] = b2;

        bytes memory clfResponse = abi.encode(uint256(100), b);

        (uint256 childPoolsLiquidity, bytes memory depositsOnTheWayIdsToDeleteInBytes) = abi.decode(
            clfResponse,
            (uint256, bytes)
        );

        uint256 gasBefore = gasleft();
        uint8[] memory depositsOnTheWayIdsToDelete = _bytesToUint8Array(
            depositsOnTheWayIdsToDeleteInBytes
        );
        uint256 gasAfter = gasleft();

        uint256 gasUsed = gasBefore - gasAfter;
        console.log("gasUsed: ", gasUsed);

        assert(depositsOnTheWayIdsToDelete.length == 2);
        assert(depositsOnTheWayIdsToDelete[0] == 5);
        assert(depositsOnTheWayIdsToDelete[1] == 0);
    }

    function test_bytesToUint8Array_1() public {
        bytes memory response = abi.encode(uint256(300), uint8(8), uint8(2));

        (uint256 totalBalance, uint8[] memory depositsOnTheWayIdsToDelete) = _decodeCLFResponse(
            response
        );

        console.log("totalBalance: ", totalBalance);
        console.log("depositsOnTheWayIdsToDelete: ", depositsOnTheWayIdsToDelete[1]);
    }

    ////////////////////////
    /// Helper functions///
    ///////////////////////

    function _fillDepositsRequestArray(uint256 count) private {
        for (uint256 i = 0; i <= count; i++) {
            _addDepositOnTheWayRequest(bytes32(0), 0, 100);
        }
    }

    function _deleteDepositOnTheWayRequestByIndex(uint256 index) private {
        s_depositsOnTheWayArray[index] = s_depositsOnTheWayArray[
            s_depositsOnTheWayArray.length - 1
        ];
        s_depositsOnTheWayArray.pop();
    }

    function _clearDepositsOnTheWay() private {
        for (uint256 i = 0; i < s_depositsOnTheWayArray.length; i++) {
            s_depositsOnTheWayArray.pop();
        }
    }
}
