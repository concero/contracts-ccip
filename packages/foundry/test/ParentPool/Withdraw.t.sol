// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "./BaseTest.t.sol";
import {ParentPool_WithdrawWrapper} from "./wrappers/ParentPool_WithdrawWrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ConceroParentPool_AmountBelowMinimum} from "contracts/ConceroParentPool.sol";

contract WithdrawTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    address liquidityProvider = makeAddr("liquidityProvider");
    IERC20 usdc = IERC20(address(vm.envAddress("USDC_BASE")));
    ParentPool_WithdrawWrapper parentPoolImplementation__withdrawWrapper;

    uint256 constant LP_BALANCE = 10_000_000_000; // 10k usdc

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        /// @dev select chain
        vm.selectFork(forkId);

        /// @dev deploy lp token
        deployLpToken();

        /// @dev deploy parentpool proxy
        deployParentPoolProxy();

        /// @dev deploy parentPool with withdrawWrapper
        vm.prank(deployer);
        parentPoolImplementation__withdrawWrapper = new ParentPool_WithdrawWrapper(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            vm.envAddress("CONCERO_ORCHESTRATOR_BASE"),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)],
            0 // slotId
        );

        /// @dev upgrade proxy
        setProxyImplementation(address(parentPoolImplementation__withdrawWrapper));

        /// @dev add functions consumer
        addFunctionsConsumer();

        /// @dev fund liquidityProvider with lp tokens
        deal(address(parentPoolImplementation__withdrawWrapper.i_lp()), liquidityProvider, LP_BALANCE);
        assertEq(IERC20(parentPoolImplementation__withdrawWrapper.i_lp()).balanceOf(liquidityProvider), LP_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            START WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function test_startWithdrawal_works() public {
        /// @dev approve the pool to spend LP tokens
        vm.startPrank(liquidityProvider);
        IERC20(parentPoolImplementation__withdrawWrapper.i_lp()).approve(address(parentPoolProxy), LP_BALANCE);

        /// @dev call startWithdrawal via proxy
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", LP_BALANCE));
        require(success, "Function call failed");
        vm.stopPrank();

        /// @dev assert liquidityProvider no longer holds tokens
        assertEq(IERC20(parentPoolImplementation__withdrawWrapper.i_lp()).balanceOf(liquidityProvider), 0);

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
        assertEq(lpSupplySnapshot, IERC20(parentPoolImplementation__withdrawWrapper.i_lp()).totalSupply());
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
        IERC20(parentPoolImplementation__withdrawWrapper.i_lp()).approve(address(parentPoolProxy), LP_BALANCE);

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
        /// @dev expect revert when calling startWithdrawal directly
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ConceroParentPool_NotParentPoolProxy(address)", address(parentPoolImplementation__withdrawWrapper)
            )
        );
        parentPoolImplementation__withdrawWrapper.startWithdrawal(LP_BALANCE);
    }
}
