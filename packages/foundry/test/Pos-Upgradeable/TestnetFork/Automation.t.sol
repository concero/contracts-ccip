// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//===== Contracts
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";

//===== Script Deploy
import {AutomationDeploy} from "../../../script/AutomationDeploy.s.sol";

//===== Interfaces
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

//===== Test Environment
import {ProtocolTestnet} from "./ProtocolTestnet.t.sol";

contract Automation is ProtocolTestnet {

    event ConceroAutomation_ForwarderAddressUpdated(address);
    function test_addForwarder() public {
        address fakeForwarder = address(0x1);

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setForwarderAddress(fakeForwarder);

        //====== Success
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_ForwarderAddressUpdated(fakeForwarder);
        automation.setForwarderAddress(fakeForwarder);
    }

    event ConceroAutomation_DonSecretVersionUpdated(uint64);
    error OwnableUnauthorizedAccount(address);
    function test_setDonHostedSecretsVersion() public {
        uint64 secretVersion = 2;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setDonHostedSecretsVersion(secretVersion);

        //====== Success
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_DonSecretVersionUpdated(secretVersion);
        automation.setDonHostedSecretsVersion(secretVersion);
    }

    event ConceroAutomation_HashSumUpdated(bytes32);
    function test_setSrcJsHashSum() public {
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setSrcJsHashSum(hashSum);

        //====== Success

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_HashSumUpdated(hashSum);
        automation.setSrcJsHashSum(hashSum);
    }

    event ConceroAutomation_EthersHashSumUpdated(bytes32);
    function test_setEthersHashSum() public {
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setEthersHashSum(hashSum);

        //====== Success

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_EthersHashSumUpdated(hashSum);
        automation.setEthersHashSum(hashSum);
    }

    event ConceroAutomation_RequestAdded(IParentPool.WithdrawRequests request);
    error ConceroAutomation_CallerNotAllowed(address);
    function test_pendingWithdrawal() public {
        IParentPool.WithdrawRequests memory _request;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        automation.addPendingWithdrawal(_request);

        vm.prank(address(masterProxy));
        vm.expectEmit();
        emit ConceroAutomation_RequestAdded(_request);
        automation.addPendingWithdrawal(_request);
    }
}