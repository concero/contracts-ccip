// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Base_Test, console, MockConceroParentPool, Vm} from "./Base_Test.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ConceroParentPool_AmountBelowMinimum} from "contracts/ConceroParentPool.sol";

contract WithdrawTest is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    address liquidityProvider = makeAddr("liquidityProvider");
    IERC20 usdc = IERC20(address(vm.envAddress("USDC_BASE")));

    uint256 constant LP_BALANCE = 10_000_000_000; // 10k usdc

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        /// @dev run the Base Test setUp
        Base_Test.setUp();

        /// @dev fund liquidityProvider with lp tokens
        deal(address(parentPoolImplementation.i_lp()), liquidityProvider, LP_BALANCE);
        assertEq(IERC20(parentPoolImplementation.i_lp()).balanceOf(liquidityProvider), LP_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            START WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function test_startWithdrawal_works() public {
        /// @dev approve the pool to spend LP tokens
        vm.startPrank(liquidityProvider);
        IERC20(parentPoolImplementation.i_lp()).approve(address(parentPoolProxy), LP_BALANCE);

        /// @dev call startWithdrawal via proxy
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", LP_BALANCE));
        require(success, "Function call failed");
        vm.stopPrank();

        /// @dev assert liquidityProvider no longer holds tokens
        assertEq(IERC20(parentPoolImplementation.i_lp()).balanceOf(liquidityProvider), 0);

        /// @dev get withdrawalId
        (, bytes memory returnData) = address(parentPoolProxy).call(
            abi.encodeWithSignature("getWithdrawalIdByLPAddress(address)", liquidityProvider)
        );
        bytes32 withdrawalId = abi.decode(returnData, (bytes32));
        assert(withdrawalId != 0);

        /// @dev use withdrawalId to get request params
        (, bytes memory returnParams) =
            address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalId));
        (address lpAddress, uint256 lpSupplySnapshot, uint256 lpAmountToBurn) =
            abi.decode(returnParams, (address, uint256, uint256));

        console.log("lpAddress:", lpAddress);
        console.log("lpSupplySnapshot:", lpSupplySnapshot);
        console.log("lpAmountToBurn:", lpAmountToBurn);

        assertEq(lpAddress, liquidityProvider);
        assertEq(lpSupplySnapshot, IERC20(parentPoolImplementation.i_lp()).totalSupply());
        assertEq(lpAmountToBurn, LP_BALANCE);
    }

    function test_startWithdrawal_reverts_if_zero_lpAmount() public {
        /// @dev expect startWithdrawal to revert with 0 lpAmount
        vm.prank(liquidityProvider);
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_AmountBelowMinimum(uint256)", 1));
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", 0));
    }

    function test_startWithdrawal_reverts_if_request_already_active() public {
        /// @dev approve the pool to spend LP tokens
        vm.startPrank(liquidityProvider);
        IERC20(parentPoolImplementation.i_lp()).approve(address(parentPoolProxy), LP_BALANCE);

        /// @dev call startWithdrawal via proxy
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", LP_BALANCE));
        require(success, "Function call failed");

        /// @dev call again, expecting revert
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_ActiveRequestNotFulfilledYet()"));
        (bool success2,) =
            address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", LP_BALANCE));
        vm.stopPrank();
    }

    function test_startWithdrawal_reverts_if_not_proxy_caller(address _caller) public {
        /// @dev make sure caller isn't the parentPoolProxy
        vm.assume(_caller != address(parentPoolProxy));

        /// @dev expect revert when calling startWithdrawal directly
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature("ConceroParentPool_NotParentPoolProxy(address)", address(parentPoolImplementation))
        );
        parentPoolImplementation.startWithdrawal(LP_BALANCE);
    }
}
