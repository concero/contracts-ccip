// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "../BaseTest.t.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Internal} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Internal.sol";
import {OrchestratorWrapper} from "./wrappers/OrchestratorWrapper.sol";

contract StartBridgeTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant LIQUIDITY_PROVIDED = 100_000_000_000;
    uint256 internal constant MIN_BRIDGE_AMOUNT = 100_000_000;
    uint256 internal constant MAX_BRIDGE_AMOUNT = 100_000_000_000;
    uint256 internal constant BATCHED_TX_THRESHOLD = 5_000_000_000; // 5,000 USDC

    address[] users;
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address user5 = makeAddr("user5");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(forkId);
        _deployOrchestratorProxy();
        _deployDexSwap();
        deployBridgesInfra();
        deployPoolsInfra();

        vm.prank(deployer);
        baseOrchestratorImplementation = new OrchestratorWrapper(
            vm.envAddress("CLF_ROUTER_BASE"),
            address(dexSwap),
            address(baseBridgeImplementation),
            address(parentPoolProxy),
            address(baseOrchestratorProxy),
            1, // IInfraStorage.Chain.base
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
        _setProxyImplementation(
            address(baseOrchestratorProxy),
            address(baseOrchestratorImplementation)
        );

        /// @dev set destination chain selector and contracts on Base
        _setDstSelectorAndPool(arbitrumChainSelector, arbitrumChildProxy);
        _setDstSelectorAndBridge(arbitrumChainSelector, arbitrumOrchestratorProxy);
        _setDstSelectorAndPool(avalancheChainSelector, avalancheChildProxy);
        _setDstSelectorAndBridge(avalancheChainSelector, avalancheOrchestratorProxy);

        deal(link, address(baseOrchestratorProxy), CCIP_FEES);

        users.push(user1);
        users.push(user2);
        users.push(user3);
        users.push(user4);
        users.push(user5);
    }

    /*//////////////////////////////////////////////////////////////
                              START BRIDGE
    //////////////////////////////////////////////////////////////*/
    function test_startBridge_success() public {
        _dealUserFundsAndApprove();

        uint256 txIdCount;

        vm.recordLogs();
        for (uint256 i; i < users.length; ++i) {
            _startBridge(users[i], USER_FUNDS, arbitrumChainSelector, address(0), 0);

            (, bytes memory updatedReturnData) = address(baseOrchestratorProxy).call(
                abi.encodeWithSignature("getBridgeTxIdsPerChain(uint64)", arbitrumChainSelector)
            );
            bytes32[] memory updatedBatchedTxId = abi.decode(updatedReturnData, (bytes32[]));
            uint256 updatedTxIdLength = updatedBatchedTxId.length;

            if (updatedTxIdLength > txIdCount) txIdCount++;
        }

        /// @dev assert s_pendingCCIPTransactionsByDstChain[_dstChainSelector] gets updated
        assertEq(txIdCount, 5 - 1); // batched users - FINAL_SENDING_USER

        Vm.Log[] memory logs = vm.getRecordedLogs();

        uint256 eventCount;
        uint256 amountSent;
        uint256 expectedLastCcipFee;
        bytes32 eventSignature = keccak256(
            "CCIPSendRequested((uint64,address,address,uint64,uint256,bool,uint64,address,uint256,bytes,(address,uint256)[],bytes[],bytes32))"
        );

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                eventCount++;

                Internal.EVM2EVMMessage memory message = abi.decode(
                    logs[i].data,
                    (Internal.EVM2EVMMessage)
                );
                Client.EVMTokenAmount[] memory tokenAmounts = message.tokenAmounts;

                amountSent = tokenAmounts[0].amount;
                expectedLastCcipFee = message.feeTokenAmount;
            }
        }

        /// @dev assert that the pendingTxs for the chain we sent to are now 0
        (, bytes memory updatedReturnData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getBridgeTxIdsPerChain(uint64)", arbitrumChainSelector)
        );
        bytes32[] memory remainingBatchedTxIds = abi.decode(updatedReturnData, (bytes32[]));
        assertEq(remainingBatchedTxIds.length, 0);

        /// @dev assert lastCcipFeeInLink is correct
        (, bytes memory retData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getLastCCIPFeeInLink(uint64)", arbitrumChainSelector)
        );
        uint256 actualAmountLastCcipFee = abi.decode(retData, (uint256));
        assertEq(expectedLastCcipFee, actualAmountLastCcipFee);

        /// @dev assert that the EVM2EVMOnRamp.CCIPSendRequested event was emitted only once
        assertEq(eventCount, 1);
        /// @dev assert that the amount sent in the single tx was equal to the funds of the 5 users who got batched
        assertEq(amountSent, 5 * USER_FUNDS);
    }

    function test_startBridge_reverts_if_not_proxy(address _caller) public {
        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
            tokenType: IInfraStorage.CCIPToken.usdc,
            amount: USER_FUNDS,
            dstChainSelector: arbitrumChainSelector,
            receiver: msg.sender,
            integrator: address(0),
            integratorFeePercent: 0
        });
        IDexSwap.SwapData[] memory dstSwapData;

        /// @dev expect revert when calling startBridge directly
        vm.prank(_caller);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ConceroBridge_OnlyProxyContext(address)",
                address(baseBridgeImplementation)
            )
        );
        baseBridgeImplementation.startBridge(bridgeData, dstSwapData);
    }

    function _startBridge(
        address _caller,
        uint256 _amount,
        uint64 _dstChainSelector,
        address _integrator,
        uint256 _integratorFeePercent
    ) internal {
        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
            tokenType: IInfraStorage.CCIPToken.usdc,
            amount: _amount,
            dstChainSelector: _dstChainSelector,
            receiver: msg.sender,
            integrator: _integrator,
            integratorFeePercent: _integratorFeePercent
        });
        IDexSwap.SwapData[] memory dstSwapData;

        vm.prank(_caller);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "bridge((uint8,uint256,uint64,address,address,uint256),(uint8,address,uint256,address,uint256,uint256,bytes)[])",
                bridgeData,
                dstSwapData
            )
        );
        require(success, "bridge call failed");
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATOR FEES
    //////////////////////////////////////////////////////////////*/
    function test_integratorFees_bridge() public {
        _dealUserFundsAndApprove();
        _startBridge(user1, USER_FUNDS, arbitrumChainSelector, integrator, INTEGRATOR_FEE_PERCENT);

        (, bytes memory retData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getIntegratorFees(address,address)", integrator, usdc)
        );
        uint256 integratorFeesEarned = abi.decode(retData, (uint256));

        uint256 expectedFeesEarned = (USER_FUNDS * INTEGRATOR_FEE_PERCENT) / INTEGRATOR_FEE_DIVISOR;

        assertEq(expectedFeesEarned, integratorFeesEarned);
    }

    function test_integratorFees_max_percent_exceeded() public {
        uint256 integratorFeePercent = INTEGRATOR_FEE_PERCENT * 3;
        _dealUserFundsAndApprove();
        _startBridge(user1, USER_FUNDS, arbitrumChainSelector, integrator, integratorFeePercent);

        (, bytes memory retData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getIntegratorFees(address,address)", integrator, usdc)
        );
        uint256 integratorFeesEarned = abi.decode(retData, (uint256));

        uint256 expectedFeesEarned = (USER_FUNDS * MAX_INTEGRATOR_FEE_PERCENT) /
            INTEGRATOR_FEE_DIVISOR;

        assertEq(expectedFeesEarned, integratorFeesEarned);
    }

    function test_integratorFees_withdraw_token() public {
        _setStorageVars();
        _dealUserFundsAndApprove();
        _startBridge(user1, USER_FUNDS, arbitrumChainSelector, integrator, INTEGRATOR_FEE_PERCENT);

        uint256 balanceBefore = IERC20(usdc).balanceOf(integrator);

        vm.prank(integrator);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("withdrawIntegratorFees(address)", usdc)
        );

        uint256 balanceAfter = IERC20(usdc).balanceOf(integrator);

        uint256 expectedFeesEarned = (USER_FUNDS * INTEGRATOR_FEE_PERCENT) / INTEGRATOR_FEE_DIVISOR;

        assertEq(expectedFeesEarned, balanceAfter - balanceBefore);
    }

    /*//////////////////////////////////////////////////////////////
                            FEE CALCULATION
    //////////////////////////////////////////////////////////////*/
    function test_ccipFee_calculation_amount_higher_than_threshold(uint256 _amount) public {
        /// @dev bound fuzzed _amount to realistic value
        _amount = bound(_amount, BATCHED_TX_THRESHOLD, MAX_BRIDGE_AMOUNT);
        _setStorageVars();

        /// @dev get the lastCCIPFeeInUsdc
        (, bytes memory lastCCIPFeeInUsdcData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getCcipFeeInUsdcDelegateCall(uint64)", arbitrumChainSelector)
        );
        uint256 lastCCIPFeeInUsdc = abi.decode(lastCCIPFeeInUsdcData, (uint256));

        /// @dev get all the fees bundled in a struct
        FeeData memory feeData = _getFeeData(_amount);

        /// @dev calculate the fee
        uint256 calculatedFee = feeData.totalFeeInUsdc -
            feeData.functionsFeeInUsdc -
            feeData.conceroFee -
            feeData.messengerGasFeeInUsdc;

        /// @dev assert the fee is expected
        assertEq(calculatedFee, lastCCIPFeeInUsdc);
    }

    function test_ccipFee_calculation_amount_lower_than_threshold(uint256 _amount) public {
        /// @dev bound fuzzed _amount to realistic value
        _amount = bound(_amount, MIN_BRIDGE_AMOUNT, BATCHED_TX_THRESHOLD);
        _setStorageVars();

        /// @dev get the lastCCIPFeeInUsdc
        (, bytes memory lastCCIPFeeInUsdcData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getCcipFeeInUsdcDelegateCall(uint64)", arbitrumChainSelector)
        );
        uint256 lastCCIPFeeInUsdc = abi.decode(lastCCIPFeeInUsdcData, (uint256));

        /// @dev get all the fees bundled in a struct
        FeeData memory feeData = _getFeeData(_amount);

        /// @dev calculate the fee
        uint256 calculatedFee = feeData.totalFeeInUsdc -
            feeData.functionsFeeInUsdc -
            feeData.conceroFee -
            feeData.messengerGasFeeInUsdc;

        /// @dev assert the fee is expected
        uint256 expectedFee = (lastCCIPFeeInUsdc * _amount) / BATCHED_TX_THRESHOLD;
        assertEq(calculatedFee, expectedFee);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function _getPendingTxsLengthPerChain(uint64 _dstChainSelector) internal returns (uint256) {
        (, bytes memory returnData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getBridgeTxIdsPerChain(uint64)", _dstChainSelector)
        );
        bytes32[] memory batchedTxs = abi.decode(returnData, (bytes32[]));
        return batchedTxs.length;
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _dealUserFundsAndApprove() internal {
        for (uint256 i; i < users.length; ++i) {
            deal(usdc, users[i], USER_FUNDS * 10);
            vm.prank(users[i]);
            IERC20(usdc).approve(address(baseOrchestratorProxy), type(uint256).max);
        }
    }
}
