// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseTest, console, Vm} from "./BaseTest.t.sol";
import {ParentPool_Wrapper, IParentPoolWrapper} from "./wrappers/ParentPool_Wrapper.sol";
import {Client} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from
    "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsRouter.sol";
import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsResponse.sol";
import {
    FunctionsCoordinator,
    FunctionsBillingConfig
} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsCoordinator.sol";

contract DepositTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev transmitter address retrieved from coordinator logs
    // https://basescan.org/address/0xd93d77789129c584a02B9Fd3BfBA560B2511Ff8A#events
    address internal constant BASE_FUNCTIONS_TRANSMITTER = 0xAdE50D64476177aAe4505DFEA094B1a0ffa49332;
    uint256 internal constant DEPOSIT_AMOUNT_USDC = 100 * 10 ** 6;
    uint256 internal constant MIN_DEPOSIT = 100_000_000;
    uint256 internal constant USDC_PRECISION = 1e6;
    uint256 internal constant WAD_PRECISION = 1e18;
    uint256 internal constant DEPOSIT_FEE_USDC = 3 * 10 ** 6;
    uint256 internal constant MAX_INDIVIDUAL_DEPOSIT = 100_000 * 1e6; // 100k usdc
    uint256 internal constant INITIAL_DIRECT_DEPOSIT = 1e6; // 1 usdc

    FunctionsRouter functionsRouter = FunctionsRouter(vm.envAddress("CLF_ROUTER_BASE"));

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        /// @dev select chain
        vm.selectFork(forkId);

        /// @dev deploy parentpool proxy
        deployParentPoolProxy();

        /// @dev deploy lp token
        deployLpToken();

        /// @dev deploy parentPool with wrapper
        parentPoolImplementation = new ParentPool_Wrapper(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            address(vm.envAddress("CLF_ROUTER_BASE")),
            address(vm.envAddress("CL_CCIP_ROUTER_BASE")),
            address(vm.envAddress("USDC_BASE")),
            address(lpToken),
            address(vm.envAddress("CONCERO_ORCHESTRATOR_BASE")),
            address(deployer),
            0,
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );

        /// @dev upgrade proxy
        setProxyImplementation(address(parentPoolImplementation));

        /// @dev set initial child pool
        /// @notice using BASE args when not testing crosschain
        (arbitrumChildProxy, arbitrumChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_PROXY_ARBITRUM"),
            vm.envAddress("LINK_BASE"), // vm.envAddress("LINK_ARBITRUM")
            vm.envAddress("CL_CCIP_ROUTER_BASE"), // vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_BASE") // vm.envAddress("USDC_ARBITRUM")
        );
        setParentPoolVars(uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")), arbitrumChildProxy);

        /// @dev add functions consumer
        addFunctionsConsumer();

        /// @dev fund parent pool with LINK for CCIP fees
        _fundLinkParentProxy(CCIP_FEES);
    }

    /*//////////////////////////////////////////////////////////////
                             START DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function test_startDeposit_Success() public {
        (bytes32 requestId,,) = _startDepositAndMonitorLogs(user1, DEPOSIT_AMOUNT_USDC);

        // Verify storage changes using the requestId
        ParentPool_Wrapper.DepositRequest memory depositRequest =
            IParentPoolWrapper(address(parentPoolProxy)).getDepositRequest(requestId);

        assertEq(depositRequest.lpAddress, address(user1));
        assertEq(depositRequest.usdcAmountToDeposit, DEPOSIT_AMOUNT_USDC);
    }

    function _startDepositAndMonitorLogs(address _caller, uint256 _amount)
        internal
        returns (bytes32 requestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels)
    {
        /// @dev fund user with USDC and approve parentPoolProxy to spend
        deal(usdc, _caller, _amount);
        vm.prank(_caller);
        IERC20(usdc).approve(address(parentPoolProxy), _amount);

        /// @dev record logs
        vm.recordLogs();

        /// @dev startDeposit
        vm.prank(_caller);
        IParentPoolWrapper(address(parentPoolProxy)).startDeposit(_amount);

        /// @dev get and verify logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 4);
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

    function test_startDeposit_RevertOnMinDeposit(uint256 _amount) public {
        vm.assume(_amount < MIN_DEPOSIT);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_AmountBelowMinimum(uint256)", MIN_DEPOSIT));
        IParentPoolWrapper(address(parentPoolProxy)).startDeposit(_amount);
    }

    function test_startDeposit_RevertNonProxyCall(address _caller) public {
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature("ConceroParentPool_NotParentPoolProxy(address)", address(parentPoolImplementation))
        );
        parentPoolImplementation.startDeposit(DEPOSIT_AMOUNT_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                            COMPLETE DEPOSIT
    //////////////////////////////////////////////////////////////*/
    function test_completeDeposit_success() public {
        /// @dev startDeposit
        (bytes32 depositRequestId, uint32 callbackGasLimit, uint96 estimatedTotalCostJuels) =
            _startDepositAndMonitorLogs(user1, DEPOSIT_AMOUNT_USDC);

        /// @dev fulfill active request
        bytes memory response = abi.encode(INITIAL_DIRECT_DEPOSIT); // 1 usdc
        _fulfillRequest(response, depositRequestId, callbackGasLimit, estimatedTotalCostJuels);

        /// @dev completeDeposit
        _completeDeposit(user1, depositRequestId);

        /// @dev assert lp tokens minted as expected
        uint256 expectedLpTokensMinted = ((DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC) * WAD_PRECISION) / USDC_PRECISION;
        uint256 actualLptokensMinted = IERC20(parentPoolImplementation.i_lp()).balanceOf(user1);
        assertEq(expectedLpTokensMinted, actualLptokensMinted);

        /// @dev assert storage has been deleted
        ParentPool_Wrapper.DepositRequest memory depositRequest =
            IParentPoolWrapper(address(parentPoolProxy)).getDepositRequest(depositRequestId);
        assertEq(depositRequest.lpAddress, address(0));
        assertEq(depositRequest.usdcAmountToDeposit, 0);
    }

    function _completeDeposit(address _caller, bytes32 _requestId) internal {
        /// @dev call completeDeposit via proxy
        vm.prank(_caller);
        (bool success,) = address(parentPoolProxy).call(abi.encodeWithSignature("completeDeposit(bytes32)", _requestId));
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
        (FunctionsResponse.FulfillResult resultCode, uint96 callbackGasCostJuels) =
            functionsRouter.fulfill(_response, err, juelsPerGas, costWithoutFulfillment, transmitter, commitment);

        console.log("Result Code:", uint8(resultCode));
        console.log("Callback Gas Cost Juels:", callbackGasCostJuels);
    }

    /*//////////////////////////////////////////////////////////////
                           LP TOKEN ISSUANCE
    //////////////////////////////////////////////////////////////*/
    function test_lpToken_integrity_multiple_depositors(uint256 _amount1, uint256 _amount2) public {
        /// @dev restrict fuzzed deposit amounts
        _amount1 = bound(_amount1, MIN_DEPOSIT + DEPOSIT_FEE_USDC, MAX_INDIVIDUAL_DEPOSIT);
        _amount2 = bound(_amount2, MIN_DEPOSIT + DEPOSIT_FEE_USDC, MAX_INDIVIDUAL_DEPOSIT);

        /// @dev startDeposit and fulfillRequest for first user
        (bytes32 depositRequestId1, uint32 callbackGasLimit1, uint96 estimatedTotalCostJuels1) =
            _startDepositAndMonitorLogs(user1, _amount1);
        bytes memory response1 = abi.encode(INITIAL_DIRECT_DEPOSIT); // 1 usdc
        _fulfillRequest(response1, depositRequestId1, callbackGasLimit1, estimatedTotalCostJuels1);

        /// @dev completeDeposit for first user
        _completeDeposit(user1, depositRequestId1);

        /// @dev assert s_depositsOnTheWayAmount is more than 0
        assertGt(IParentPoolWrapper(address(parentPoolProxy)).getDepositsOnTheWayAmount(), 0);

        /// @dev we need the totalSupply to calculate user2's owed lp tokens
        uint256 lpTotalSupplyBeforeSecondDeposit = IERC20(parentPoolImplementation.i_lp()).totalSupply();

        /// @dev startDeposit and fulfillRequest for second user
        (bytes32 depositRequestId2, uint32 callbackGasLimit2, uint96 estimatedTotalCostJuels2) =
            _startDepositAndMonitorLogs(user2, _amount2);
        bytes memory response2 = abi.encode(INITIAL_DIRECT_DEPOSIT + (_amount1 / 2)); // 1 usdc + (first deposit / parent+child)
        _fulfillRequest(response2, depositRequestId2, callbackGasLimit2, estimatedTotalCostJuels2);

        /// @dev get the depositRequest for user2 to get childPoolsLiquiditySnapshot
        ParentPool_Wrapper.DepositRequest memory depositRequest =
            IParentPoolWrapper(address(parentPoolProxy)).getDepositRequest(depositRequestId2);

        /// @dev calculate totalCrossChainLiquidity
        uint256 totalCrossChainLiquidity =
            _calculateTotalCrossChainLiquidity(depositRequest.childPoolsLiquiditySnapshot);

        /// @dev completeDeposit for second user
        _completeDeposit(user2, depositRequestId2);

        /// @dev assert user2 lp tokens minted as expected
        uint256 expectedLpTokensMintedUser2 =
            _calculateExpectedLpTokensMinted(_amount2, totalCrossChainLiquidity, lpTotalSupplyBeforeSecondDeposit);

        uint256 actualLptokensMintedUser2 = IERC20(parentPoolImplementation.i_lp()).balanceOf(user2);
        assertEq(expectedLpTokensMintedUser2, actualLptokensMintedUser2);
    }

    /*//////////////////////////////////////////////////////////////
                              CCIP RECEIVE
    //////////////////////////////////////////////////////////////*/
    function test_ccipReceive() public {
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));

        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({token: vm.envAddress("USDC_BASE"), amount: 100000000});

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked("test")),
            sourceChainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            sender: abi.encode(user1),
            data: abi.encode(address(0), address(0), 0),
            destTokenAmounts: destTokenAmounts
        });

        IAny2EVMMessageReceiver(address(parentPoolProxy)).ccipReceive(message);
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _calculateTotalCrossChainLiquidity(uint256 _childPoolsLiquiditySnapshot) internal returns (uint256) {
        uint256 totalCrossChainLiquidity = (
            IERC20(usdc).balanceOf(address(parentPoolProxy))
                + IParentPoolWrapper(address(parentPoolProxy)).getLoansInUse()
                + IParentPoolWrapper(address(parentPoolProxy)).getDepositsOnTheWayAmount()
                - IParentPoolWrapper(address(parentPoolProxy)).getDepositFeeAmount()
        ) + _childPoolsLiquiditySnapshot;

        return totalCrossChainLiquidity;
    }

    function _calculateExpectedLpTokensMinted(
        uint256 _depositAmount,
        uint256 _totalCrossChainLiquidity,
        uint256 _lpTotalSupply
    ) internal returns (uint256) {
        uint256 amountDepositedConverted = ((_depositAmount - DEPOSIT_FEE_USDC) * WAD_PRECISION) / USDC_PRECISION;
        uint256 crossChainBalanceConverted = (_totalCrossChainLiquidity * WAD_PRECISION) / USDC_PRECISION;

        uint256 expectedLpTokensMinted = (
            ((crossChainBalanceConverted + amountDepositedConverted) * _lpTotalSupply) / crossChainBalanceConverted
        ) - _lpTotalSupply;

        return expectedLpTokensMinted;
    }
}
