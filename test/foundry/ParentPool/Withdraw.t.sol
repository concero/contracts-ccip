// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {WithdrawAmountBelowMinimum} from "contracts/ParentPool.sol";
import {BaseTest, console, Vm} from "../utils/BaseTest.t.sol";
import {ParentPoolWrapper} from "./wrappers/ParentPoolWrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {WithdrawAmountBelowMinimum} from "contracts/ParentPool.sol";
import {FunctionsRouter, IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {FunctionsCoordinator, FunctionsBillingConfig} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";
import {LPToken} from "contracts/LPToken.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {ParentPool} from "contracts/ParentPool.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";

contract WithdrawTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                                VARIABLES
     //////////////////////////////////////////////////////////////*/
    address liquidityProvider = makeAddr("liquidityProvider");
    IERC20 usdc = IERC20(address(vm.envAddress("USDC_BASE")));
    ParentPoolWrapper parentPoolImplementationWrapper;
    FunctionsRouter functionsRouter = FunctionsRouter(vm.envAddress("CLF_ROUTER_BASE"));

    uint256 constant LP_BALANCE_USDC = 10 * USDC_DECIMALS;
    uint256 constant LP_BALANCE_LPT = 10 ether;
    uint256 constant CHILD_POOLS_LIQUIDITY_USDC = 300_000 * USDC_DECIMALS;
    uint256 constant PARENT_POOL_LIQUIDITY_USDC = 100_000 * USDC_DECIMALS;

    /*//////////////////////////////////////////////////////////////
                                  SETUP
     //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(baseAnvilForkId);
        deployParentPoolProxy();
        deployLpToken();

        /// @dev deploy parentPool with withdrawWrapper
        vm.prank(deployer);
        parentPoolImplementationWrapper = new ParentPoolWrapper(
            address(parentPoolProxy),
            address(parentPoolCLFCLA),
            vm.envAddress("PARENT_POOL_AUTOMATION_FORWARDER_BASE_SEPOLIA"),
            vm.envAddress("LINK_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            address(baseOrchestratorProxy),
            vm.envAddress("CLF_ROUTER_BASE"),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

        _setProxyImplementation(address(parentPoolProxy), address(parentPoolImplementationWrapper));

        vm.prank(address(parentPoolProxy));
        LPToken(address(lpToken)).mint(liquidityProvider, LP_BALANCE_LPT);
        assertEq(IERC20(lpToken).balanceOf(liquidityProvider), LP_BALANCE_LPT);
        assertEq(IERC20(lpToken).totalSupply(), LP_BALANCE_LPT);
    }

    /*//////////////////////////////////////////////////////////////
                             START WITHDRAWAL
     //////////////////////////////////////////////////////////////*/
    function test_startWithdrawal() public {
        uint256 lptAmountToBurn = 2 ether;

        vm.startPrank(liquidityProvider);

        IERC20(lpToken).approve(address(parentPoolProxy), lptAmountToBurn);
        ParentPool(payable(parentPoolProxy)).startWithdrawal(lptAmountToBurn);

        // Assert remaining balance
        uint256 expectedRemainingBalance = LP_BALANCE_LPT - lptAmountToBurn;
        assertEq(IERC20(lpToken).balanceOf(liquidityProvider), expectedRemainingBalance);

        // Get withdrawal ID and assert
        bytes32 withdrawalId = ParentPool(payable(parentPoolProxy)).getWithdrawalIdByLPAddress(
            liquidityProvider
        );
        assert(withdrawalId != 0);

        // Get withdrawal request params
        (
            address lpAddress,
            uint256 lpAmountToBurn,
            uint256 amountReadyToWithdrawUSDC
        ) = ParentPoolWrapper(payable(parentPoolProxy)).getWithdrawRequestParams(withdrawalId);

        // Assert withdrawal params
        assertEq(lpAddress, liquidityProvider);
        assertEq(lpAmountToBurn, lptAmountToBurn);
        assertEq(amountReadyToWithdrawUSDC, 0);
    }

    function test_startWithdrawalRevertsIfZeroLpAmount() public {
        vm.prank(liquidityProvider);
        vm.expectRevert(abi.encodeWithSignature("WithdrawAmountBelowMinimum(uint256)", 1 ether));
        ParentPool(payable(parentPoolProxy)).startWithdrawal(0);
    }

    function test_startWithdrawalRevertsIfRequestAlreadyActive() public {
        vm.startPrank(liquidityProvider);
        IERC20(lpToken).approve(address(parentPoolProxy), LP_BALANCE_LPT);

        ParentPool(payable(parentPoolProxy)).startWithdrawal(LP_BALANCE_LPT);

        /// @dev call again, expecting revert
        vm.expectRevert(abi.encodeWithSignature("WithdrawalRequestAlreadyExists()"));
        ParentPool(payable(parentPoolProxy)).startWithdrawal(LP_BALANCE_LPT);
    }

    /*//////////////////////////////////////////////////////////////
                           COMPLETE WITHDRAWAL
     //////////////////////////////////////////////////////////////*/
    //    function test_completeWithdrawal_works() public {
    //        (
    //            bytes32 requestId,
    //            uint32 callbackGasLimit,
    //            uint96 estimatedTotalCostJuels
    //        ) = _startWithdrawalAndMonitorLogs();
    //        _fulfillRequest(requestId, CHILD_POOLS_LIQUIDITY_USDC);
    //        _completeWithdrawal();
    //    }

    function _startWithdrawalAndMonitorLogs()
        internal
        returns (bytes32 requestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels)
    {
        uint256 lptAmountToBurn = 2 ether;
        /// @dev record the logs so we can find the CLF request ID
        vm.recordLogs();

        /// @dev approve the pool to spend LP tokens
        vm.startPrank(liquidityProvider);
        IERC20(lpToken).approve(address(parentPoolProxy), lptAmountToBurn);

        /// @dev call startWithdrawal via proxy
        vm.startPrank(liquidityProvider);
        ParentPool(payable(parentPoolProxy)).startWithdrawal(lptAmountToBurn);

        /// @dev get and verify logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 6);
        /// @dev find the RequestStart log and params we need for commitment
        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].topics[0] ==
                keccak256(
                    "RequestStart(bytes32,bytes32,uint64,address,address,address,bytes,uint16,uint32,uint96)"
                )
            ) {
                /// @dev get the values we need
                requestId = entries[i].topics[1];
                (, , , , , callbackGasLimit, estimatedTotalCostJuels) = abi.decode(
                    entries[i].data,
                    (address, address, address, bytes, uint16, uint32, uint96)
                );
                break;
            }
        }

        return (requestId, callbackGasLimit, estimatedTotalCostJuels);
    }

    function _fulfillRequest(bytes32 requestId, bytes memory response) internal {
        vm.prank(vm.envAddress("CLF_ROUTER_BASE"));
        FunctionsClient(address(parentPoolProxy)).handleOracleFulfillment(requestId, response, "");
    }

    //    function _completeWithdrawal() internal {
    // /// @dev get withdrawalId
    // (, bytes memory returnData) = address(parentPoolProxy).call(
    //     abi.encodeWithSignature("getWithdrawalIdByLPAddress(address)", liquidityProvider)
    // );
    // bytes32 withdrawalId = abi.decode(returnData, (bytes32));
    // assert(withdrawalId != 0);
    // /// @dev skip time to after the withdrawal cool-off period
    // vm.warp(block.timestamp + 8 days + 1);
    // // checkUpkeep should evaluate to true for
    // /// @dev use withdrawalId to get request params
    // (, bytes memory returnParams) =
    //     address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalId));
    // (,,, uint256 amountToWithdraw) = abi.decode(returnParams, (address, uint256, uint256, uint256));
    // console.log("amountToWithdraw:", amountToWithdraw);
    // assertGt(amountToWithdraw, 0);
    // /// @dev call the completeWithdrawal
    // vm.prank(liquidityProvider);
    // (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("completeWithdrawal()"));
    // require(success, "Function call failed");
    //    }
}
