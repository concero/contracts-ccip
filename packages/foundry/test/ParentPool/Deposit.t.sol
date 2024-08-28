// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest, console, Vm} from "./BaseTest.t.sol";
import {ParentPool_Wrapper, IParentPoolWrapper} from "./wrappers/ParentPool_Wrapper.sol";
import {Client} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {FunctionsCoordinator, FunctionsBillingConfig} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";
import {Internal} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Internal.sol";

contract Deposit is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant DEPOSIT_AMOUNT_USDC = 100 * 10 ** 6;
    uint256 internal constant MIN_DEPOSIT = 1 * 1_000_000;
    /// @dev transmitter address retrieved from coordinator logs
    address internal constant BASE_FUNCTIONS_TRANSMITTER =
        0xAdE50D64476177aAe4505DFEA094B1a0ffa49332;
    uint256 internal constant CCIP_FEES = 10 * 1e18;
    uint256 internal constant USDC_PRECISION = 1e6;
    uint256 internal constant WAD_PRECISION = 1e18;
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * 10 ** 6;
    uint256 internal constant MAX_INDIVIDUAL_DEPOSIT = 100_000 * 1e6; // 100k usdc

    /// @dev WETH https://basescan.org/token/0x4200000000000000000000000000000000000006
    address internal constant WRAPPED_NATIVE_BASE = 0x4200000000000000000000000000000000000006;

    FunctionsRouter functionsRouter = FunctionsRouter(vm.envAddress("CLF_ROUTER_BASE"));

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(forkId);
        deployParentPoolProxy();
        deployLpToken();

        parentPoolImplementation = new ParentPool_Wrapper(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(lpToken),
            vm.envAddress("CONCERO_AUTOMATION_BASE"),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

        setProxyImplementation(address(parentPoolImplementation));
        setParentPoolVars();
        addFunctionsConsumer();
    }

    /*//////////////////////////////////////////////////////////////
                             START DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function test_startDeposit_Success() public {
        (bytes32 requestId, , ) = _startDepositAndMonitorLogs(user1, DEPOSIT_AMOUNT_USDC);

        // Verify storage changes using the requestId
        ParentPool_Wrapper.DepositRequest memory depositRequest = IParentPoolWrapper(
            address(parentPoolProxy)
        ).getDepositRequest(requestId);

        assertEq(depositRequest.lpAddress, address(user1));
        assertEq(depositRequest.usdcAmountToDeposit, DEPOSIT_AMOUNT_USDC);
    }

    function _startDepositAndMonitorLogs(
        address _caller,
        uint256 _amount
    )
        internal
        returns (bytes32 requestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels)
    {
        vm.recordLogs();

        vm.prank(_caller);
        IParentPoolWrapper(address(parentPoolProxy)).startDeposit(_amount);

        /// @dev get and verify logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 4);
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

    function test_startDeposit_RevertOnMinDeposit(uint256 _amount) public {
        vm.assume(_amount < MIN_DEPOSIT);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("ConceroParentPool_AmountBelowMinimum(uint256)", MIN_DEPOSIT)
        );
        IParentPoolWrapper(address(parentPoolProxy)).startDeposit(_amount);
    }

    function test_startDeposit_RevertNonProxyCall(address _caller) public {
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ConceroParentPool_NotParentPoolProxy(address)",
                address(parentPoolImplementation)
            )
        );
        parentPoolImplementation.startDeposit(DEPOSIT_AMOUNT_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                            COMPLETE DEPOSIT
    //////////////////////////////////////////////////////////////*/
    /// @dev this will fail on this branch because LINK is used for CCIP fees in this test
    function test_completeDeposit_success() public {
        /// @dev fund user with USDC and approve parentPoolProxy to spend
        deal(usdc, user1, DEPOSIT_AMOUNT_USDC);
        vm.prank(user1);
        IERC20(usdc).approve(address(parentPoolProxy), DEPOSIT_AMOUNT_USDC);

        /// @dev fund the parentPoolProxy with LINK to pay for CCIP
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), CCIP_FEES);

        /// @dev startDeposit
        (
            bytes32 depositRequestId,
            uint32 callbackGasLimit,
            uint96 estimatedTotalCostJuels
        ) = _startDepositAndMonitorLogs(user1, DEPOSIT_AMOUNT_USDC);

        /// @dev fulfill active request
        bytes memory response = abi.encode(MIN_DEPOSIT); // 1 usdc
        _fulfillRequest(response, depositRequestId, callbackGasLimit, estimatedTotalCostJuels);

        /// @dev completeDeposit
        _completeDeposit(user1, depositRequestId);

        /// @dev assert lp tokens minted as expected
        uint256 expectedLpTokensMinted = ((DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC) *
            WAD_PRECISION) / USDC_PRECISION;
        uint256 actualLptokensMinted = IERC20(parentPoolImplementation.i_lp()).balanceOf(user1);
        assertEq(expectedLpTokensMinted, actualLptokensMinted);

        /// @dev assert storage has been deleted
        ParentPool_Wrapper.DepositRequest memory depositRequest = IParentPoolWrapper(
            address(parentPoolProxy)
        ).getDepositRequest(depositRequestId);
        assertEq(depositRequest.lpAddress, address(0));
        assertEq(depositRequest.usdcAmountToDeposit, 0);
    }

    function test_completeDeposit_CCIP_native_fees() public {
        /// @dev fund user with USDC and approve parentPoolProxy to spend
        deal(usdc, user1, DEPOSIT_AMOUNT_USDC);
        vm.prank(user1);
        IERC20(usdc).approve(address(parentPoolProxy), DEPOSIT_AMOUNT_USDC);

        /// @dev fund the parentPoolProxy with ETH to pay for CCIP
        vm.deal(address(parentPoolProxy), CCIP_FEES);

        /// @dev startDeposit
        (
            bytes32 depositRequestId,
            uint32 callbackGasLimit,
            uint96 estimatedTotalCostJuels
        ) = _startDepositAndMonitorLogs(user1, DEPOSIT_AMOUNT_USDC);

        /// @dev fulfill active request
        bytes memory response = abi.encode(MIN_DEPOSIT); // 1 usdc
        _fulfillRequest(response, depositRequestId, callbackGasLimit, estimatedTotalCostJuels);

        /// @dev completeDeposit
        vm.recordLogs();
        _completeDeposit(user1, depositRequestId);

        /// @dev assert lp tokens minted as expected
        uint256 expectedLpTokensMinted = ((DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC) *
            WAD_PRECISION) / USDC_PRECISION;
        uint256 actualLptokensMinted = IERC20(parentPoolImplementation.i_lp()).balanceOf(user1);
        assertEq(expectedLpTokensMinted, actualLptokensMinted);

        /// @dev assert storage has been deleted
        ParentPool_Wrapper.DepositRequest memory depositRequest = IParentPoolWrapper(
            address(parentPoolProxy)
        ).getDepositRequest(depositRequestId);
        assertEq(depositRequest.lpAddress, address(0));
        assertEq(depositRequest.usdcAmountToDeposit, 0);

        /// @dev assert wrapped native token was used for fees
        address feeToken;
        uint256 feeTokenAmount;

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256(
            "CCIPSendRequested((uint64,address,address,uint64,uint256,bool,uint64,address,uint256,bytes,(address,uint256)[],bytes[],bytes32))"
        );

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                Internal.EVM2EVMMessage memory message = abi.decode(
                    logs[i].data,
                    (Internal.EVM2EVMMessage)
                );

                feeToken = message.feeToken;
                feeTokenAmount = message.feeTokenAmount;
            }
        }

        assertEq(feeToken, WRAPPED_NATIVE_BASE);
        assertGt(feeTokenAmount, 0);
    }

    function _completeDeposit(address _caller, bytes32 _requestId) internal {
        /// @dev call completeDeposit via proxy
        vm.prank(_caller);
        (bool success, ) = address(parentPoolProxy).call(
            abi.encodeWithSignature("completeDeposit(bytes32)", _requestId)
        );
        require(success, "completeDeposit call failed");
    }

    function _fulfillRequest(
        bytes memory _response,
        bytes32 _requestId,
        uint32 _callbackGasLimit,
        uint96 _estimatedTotalCostJuels
    ) internal {
        /// @dev get coordinator to call functions router
        address coordinator = functionsRouter.getContractById(vm.envBytes32("CLF_DONID_BASE"));

        /// @dev create fulfill params
        bytes memory err = "";
        uint96 juelsPerGas = 1_000_000_000; // current rate of juels/gas
        uint96 costWithoutFulfillment = 0; // The cost of processing the request (in Juels of LINK ), without fulfillment
        address transmitter = BASE_FUNCTIONS_TRANSMITTER;

        /// @dev get timeoutTimestamp from billing config
        FunctionsBillingConfig memory billingConfig = FunctionsCoordinator(coordinator).getConfig();
        uint32 timeoutTimestamp = uint32(block.timestamp + billingConfig.requestTimeoutSeconds);

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
            timeoutTimestamp // timeoutTimestamp
        );

        /// @dev prank the coordinator to call fulfill on functionsRouter
        vm.prank(coordinator);
        (FunctionsResponse.FulfillResult resultCode, uint96 callbackGasCostJuels) = functionsRouter
            .fulfill(_response, err, juelsPerGas, costWithoutFulfillment, transmitter, commitment);

        console.log("Result Code:", uint8(resultCode));
        console.log("Callback Gas Cost Juels:", callbackGasCostJuels);
    }

    /*//////////////////////////////////////////////////////////////
                           LP TOKEN ISSUANCE
    //////////////////////////////////////////////////////////////*/
    function test_lpToken_integrity_multiple_depositors(uint256 _amount1, uint256 _amount2) public {
        /// @dev restrict fuzzed deposit amounts
        vm.assume(
            (_amount1 > MIN_DEPOSIT + DEPOSIT_FEE_USDC) && (_amount1 < MAX_INDIVIDUAL_DEPOSIT)
        );
        vm.assume(
            (_amount2 > MIN_DEPOSIT + DEPOSIT_FEE_USDC) && (_amount2 < MAX_INDIVIDUAL_DEPOSIT)
        );

        /// @dev fund users with USDC and approve parentPoolProxy to spend
        deal(usdc, user1, _amount1);
        vm.prank(user1);
        IERC20(usdc).approve(address(parentPoolProxy), _amount1);
        deal(usdc, user2, _amount2);
        vm.prank(user2);
        IERC20(usdc).approve(address(parentPoolProxy), _amount2);

        /// @dev fund the parentPoolProxy with LINK to pay for CCIP
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), CCIP_FEES);

        /// @dev startDeposit and fulfillRequest for first user
        (
            bytes32 depositRequestId1,
            uint32 callbackGasLimit1,
            uint96 estimatedTotalCostJuels1
        ) = _startDepositAndMonitorLogs(user1, _amount1);
        bytes memory response1 = abi.encode(MIN_DEPOSIT); // 1 usdc
        _fulfillRequest(response1, depositRequestId1, callbackGasLimit1, estimatedTotalCostJuels1);

        /// @dev completeDeposit for first user
        _completeDeposit(user1, depositRequestId1);

        /// @dev assert s_depositsOnTheWayAmount is more than 0
        assertGt(IParentPoolWrapper(address(parentPoolProxy)).getDepositsOnTheWayAmount(), 0);

        /// @dev we need the totalSupply to calculate user2's owed lp tokens
        uint256 lpTotalSupplyBeforeSecondDeposit = IERC20(parentPoolImplementation.i_lp())
            .totalSupply();

        /// @dev startDeposit and fulfillRequest for second user
        (
            bytes32 depositRequestId2,
            uint32 callbackGasLimit2,
            uint96 estimatedTotalCostJuels2
        ) = _startDepositAndMonitorLogs(user2, _amount2);
        bytes memory response2 = abi.encode(MIN_DEPOSIT + (_amount1 / 2)); // 1 usdc + (first deposit / parent+child)
        _fulfillRequest(response2, depositRequestId2, callbackGasLimit2, estimatedTotalCostJuels2);

        /// @dev we need logs for second user's completeDeposit to get the totalCrossChainLiquiditySnapshot
        vm.recordLogs();
        /// @dev completeDeposit for second user
        _completeDeposit(user2, depositRequestId2);

        /// @dev get and verify logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        /// @dev find the log and param we need to calculate expected LP tokens
        uint256 totalCrossChainLiquiditySnapshot;
        for (uint256 i = 0; i < entries.length; ++i) {
            if (
                entries[i].topics[0] ==
                keccak256(
                    "ConceroParentPool_DepositCompleted(bytes32,address,uint256,uint256,uint256)"
                )
            ) {
                (, , totalCrossChainLiquiditySnapshot) = abi.decode(
                    entries[i].data,
                    (uint256, uint256, uint256)
                );
                break;
            }
        }

        /// @dev assert user2 lp tokens minted as expected
        uint256 amountDepositedConverted = ((_amount2 - DEPOSIT_FEE_USDC) * WAD_PRECISION) /
            USDC_PRECISION;
        uint256 crossChainBalanceConverted = (totalCrossChainLiquiditySnapshot * WAD_PRECISION) /
            USDC_PRECISION;

        uint256 expectedLpTokensMintedUser2 = (((crossChainBalanceConverted +
            amountDepositedConverted) * lpTotalSupplyBeforeSecondDeposit) /
            crossChainBalanceConverted) - lpTotalSupplyBeforeSecondDeposit;

        uint256 actualLptokensMintedUser2 = IERC20(parentPoolImplementation.i_lp()).balanceOf(
            user2
        );
        assertEq(expectedLpTokensMintedUser2, actualLptokensMintedUser2);
    }

    /*//////////////////////////////////////////////////////////////
                              CCIP RECEIVE
    //////////////////////////////////////////////////////////////*/
    function test_ccipReceive() public {
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));

        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: vm.envAddress("USDC_BASE"),
            amount: 100000000
        });

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked("test")),
            sourceChainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            sender: abi.encode(user1),
            data: abi.encode(address(0), address(0), 0),
            destTokenAmounts: destTokenAmounts
        });

        IAny2EVMMessageReceiver(address(parentPoolProxy)).ccipReceive(message);
    }
}
