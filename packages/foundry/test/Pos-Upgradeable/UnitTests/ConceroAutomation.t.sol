// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {AutomationDeploy} from "../../../script/AutomationDeploy.s.sol";

import {ConceroAutomation} from "contracts/ConceroAutomation.sol";

import {IPool} from "contracts/Interfaces/IPool.sol";

import {USDC} from "../../Mocks/USDC.sol";

contract ConceroAutomationTest is Test {
    //======== Instantiate Script
    AutomationDeploy autoDeploy;

    //======== Instantiate Contract
    ConceroAutomation automation;

    //======= Variables
    address Tester = makeAddr("Tester");
    address User = makeAddr("User");
    address masterProxy = makeAddr("masterProxy");
    address usdc = makeAddr("USDC");

    function setUp() public {
        //======== Deploy Scripts
        autoDeploy = new AutomationDeploy();

        //======== Deploy Automation
        automation = autoDeploy.run(
            0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000, //_donId
            15, //_subscriptionId
            2, //_slotId
            0xf9B8fc078197181C841c296C876945aaa425B278, //_router,
            masterProxy,
            Tester //_owner
        );
    }

    //setForwarderAddress
    event ConceroAutomation_ForwarderAddressUpdated(address);
    function test_setForwarderAddress() public {
        address forwarder = address(0x01);

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_ForwarderAddressUpdated(forwarder);
        automation.setForwarderAddress(forwarder);
    }

    error OwnableUnauthorizedAccount(address);
    function test_setForwarderAddressRevert() public {
        address forwarder = address(0x01);
        
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setForwarderAddress(forwarder);
    }

    //setDonHostedSecretsVersion
    event ConceroAutomation_DonSecretVersionUpdated(uint64);
    function test_setDonHosted() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_DonSecretVersionUpdated(0);
        automation.setDonHostedSecretsVersion(0);
    }

    function test_setDonHostedRevert() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setDonHostedSecretsVersion(0);
    }

    //addPendingWithdrawal
    event ConceroAutomation_RequestAdded(address);
    function test_addPendingWithdraw() public {

        vm.prank(masterProxy);
        vm.expectEmit();
        emit ConceroAutomation_RequestAdded(User);
        automation.addPendingWithdrawal(User);
    }

    error ConceroAutomation_CallerNotAllowed(address);
    function test_addPendingWithdrawRevert() public {        
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        automation.addPendingWithdrawal(User);
    }
}