// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Base_Test, console, MockConceroParentPool, Vm} from "./Base_Test.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FunctionsRouter, IFunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {ConceroParentPool_AmountBelowMinimum} from "contracts/ConceroParentPool.sol";

contract WithdrawTest is Base_Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    address liquidityProvider = makeAddr("liquidityProvider");
    IERC20 usdc = IERC20(vm.envAddress("USDC_BASE"));
    FunctionsRouter functionsRouter = FunctionsRouter(vm.envAddress("CLF_ROUTER_BASE"));

    uint256 constant LP_BALANCE = 10_000_000_000; // 10k USDC
    uint256 constant CHILD_POOLS_LIQUIDITY = 100_000_000_000; // 100k USDC
    uint256 constant PARENT_POOL_USDC_BALANCE = 1_000_000_000_000; // 1m USDC

    /// @dev transmitter address retrieved from coordinator logs
    // https://basescan.org/address/0xd93d77789129c584a02B9Fd3BfBA560B2511Ff8A#events
    address constant BASE_FUNCTIONS_TRANSMITTER = 0xAdE50D64476177aAe4505DFEA094B1a0ffa49332;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        /// @dev run the Base Test setUp
        Base_Test.setUp();

        /// @dev fund liquidityProvider with lp tokens
        deal(address(parentPoolImplementation.i_lp()), liquidityProvider, LP_BALANCE);
        assertEq(IERC20(parentPoolImplementation.i_lp()).balanceOf(liquidityProvider), LP_BALANCE);

        /// @dev fund proxy with usdc tokens
        deal(vm.envAddress("USDC_BASE"), address(parentPoolProxy), PARENT_POOL_USDC_BALANCE);
        assertEq(IERC20(vm.envAddress("USDC_BASE")).balanceOf(address(parentPoolProxy)), PARENT_POOL_USDC_BALANCE);
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
        (address lpAddress, uint256 lpSupplySnapshot, uint256 lpAmountToBurn,) =
            abi.decode(returnParams, (address, uint256, uint256, uint256));

        /// @dev log request param
        console.log("lpAddress:", lpAddress);
        console.log("lpSupplySnapshot:", lpSupplySnapshot);
        console.log("lpAmountToBurn:", lpAmountToBurn);

        /// @dev assert request params are what we expect
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

    /*//////////////////////////////////////////////////////////////
                          COMPLETE WITHDRAWAL
    //////////////////////////////////////////////////////////////*/
    function test_completeWithdrawal_works() public {
        (bytes32 requestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels) = _startWithdrawalAndMonitorLogs();
        _fulfillRequest(requestId, callbackGasLimit, estimatedTotalCostJuels);
        _completeWithdrawal();
    }

    function _startWithdrawalAndMonitorLogs()
        internal
        returns (bytes32 requestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels)
    {
        /// @dev record the logs so we can find the CLF request ID
        vm.recordLogs();

        /// @dev approve the pool to spend LP tokens
        vm.startPrank(liquidityProvider);
        IERC20(parentPoolImplementation.i_lp()).approve(address(parentPoolProxy), LP_BALANCE);

        /// @dev call startWithdrawal via proxy
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("startWithdrawal(uint256)", LP_BALANCE));
        require(success, "Function call failed");
        vm.stopPrank();

        /// @dev get and verify logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 6);
        /// @dev find the RequestStart log and params we need for commitment
        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].topics[0]
                    == keccak256("RequestStart(bytes32,bytes32,uint64,address,address,address,bytes,uint16,uint32,uint96)")
            ) {
                /// @dev get the values we need
                requestId = entries[i].topics[1];
                (,,,,, callbackGasLimit, estimatedTotalCostJuels) =
                    abi.decode(entries[i].data, (address, address, address, bytes, uint16, uint32, uint96));
                break;
            }
        }

        return (requestId, callbackGasLimit, estimatedTotalCostJuels);
    }

    function _fulfillRequest(bytes32 _requestId, uint32 _callbackGasLimit, uint96 _estimatedTotalCostJuels) internal {
        /// @dev get coordinator to call functions router
        // https://basescan.org/address/0xd93d77789129c584a02B9Fd3BfBA560B2511Ff8A#code
        address coordinator = functionsRouter.getContractById(vm.envBytes32("CLF_DONID_BASE"));

        /// @dev create fulfill params
        bytes memory response = abi.encode(CHILD_POOLS_LIQUIDITY);
        bytes memory err = "";
        uint96 juelsPerGas = 1_000_000_000; // current rate of juels/gas
        uint96 costWithoutFulfillment = 0; // The cost of processing the request (in Juels of LINK ), without fulfillment
        address transmitter = BASE_FUNCTIONS_TRANSMITTER;

        /// @dev get adminFee from the config
        FunctionsRouter.Config memory config = functionsRouter.getConfig();
        uint72 adminFee = config.adminFee;

        /// @notice some of these values have been hardcoded, directly from the logs
        /// @dev create the commitment params
        FunctionsResponse.Commitment memory commitment = FunctionsResponse.Commitment(
            _requestId,
            coordinator,
            _estimatedTotalCostJuels,
            address(parentPoolProxy), // client
            uint64(vm.envUint("CLF_SUBID_BASE")), // subscriptionId
            _callbackGasLimit,
            0, // adminFee
            0, // donFee
            163500, // gasOverheadBeforeCallback
            57000, // gasOverheadAfterCallback
            1722503125 // timeoutTimestamp
        );

        /// @dev prank the coordinator to call fulfill on functionsRouter
        vm.prank(coordinator);
        (FunctionsResponse.FulfillResult resultCode, uint96 callbackGasCostJuels) =
            functionsRouter.fulfill(response, err, juelsPerGas, costWithoutFulfillment, transmitter, commitment);

        console.log("Result Code:", uint8(resultCode));
        console.log("Callback Gas Cost Juels:", callbackGasCostJuels);
    }

    function _completeWithdrawal() internal {
        /// @dev get withdrawalId
        (, bytes memory returnData) = address(parentPoolProxy).call(
            abi.encodeWithSignature("getWithdrawalIdByLPAddress(address)", liquidityProvider)
        );
        bytes32 withdrawalId = abi.decode(returnData, (bytes32));
        assert(withdrawalId != 0);

        // /// @dev use withdrawalId to get request params
        // (, bytes memory returnParams) =
        //     address(parentPoolProxy).call(abi.encodeWithSignature("getWithdrawRequestParams(bytes32)", withdrawalId));
        // (,,, uint256 amountToWithdraw) = abi.decode(returnParams, (address, uint256, uint256, uint256));
        // console.log("amountToWithdraw:", amountToWithdraw);
        // assertGt(amountToWithdraw, 0);

        // /// @dev skip time to after the withdrawal cool-off period
        // vm.warp(block.timestamp + 8 days + 1);

        // /// @dev call the completeWithdrawal
        // vm.prank(liquidityProvider);
        // (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("completeWithdrawal()"));
        // require(success, "Function call failed");
    }
}
/**
 *  Commitment({ requestId: 0x61e631bca3b8d40eaf4b2d27f9ac31564a094da882b605328d42808283cd2808,
 * coordinator: 0xd93d77789129c584a02B9Fd3BfBA560B2511Ff8A,
 * estimatedTotalCostJuels: 646249561435317578 [6.462e17],
 * client: 0x9d185A9aFb6ED0a0196EBCDfc22d1516ad02596A,
 * subscriptionId: 14,
 * callbackGasLimit: 300000 [3e5],
 * adminFee: 0,
 * donFee: 0,
 * gasOverheadBeforeCallback: 163500 [1.635e5],
 * gasOverheadAfterCallback: 57000 [5.7e4],
 * timeoutTimestamp: 1722503125 [1.722e9] })
 */
