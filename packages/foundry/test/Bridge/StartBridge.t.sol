// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {BaseTest, console, Vm} from "../utils/BaseTest.t.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {IInfraOrchestrator} from "contracts/Interfaces/IInfraOrchestrator.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {InfraOrchestratorWrapper} from "./wrappers/InfraOrchestratorWrapper.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";

contract StartBridge is BaseTest {
    function setUp() public override {
        super.setUp();

        (
            address clfRouter,
            address dexSwap,
            address conceroBridge,
            address pool,
            address infraProxy,
            uint8 chainIndex,
            address[3] memory messengers
        ) = _getBaseInfraImplementationConstructorArgs();

        mintLink(address(baseOrchestratorProxy), LINK_INIT_BALANCE);

        vm.prank(deployer);
        baseOrchestratorImplementation = new InfraOrchestratorWrapper(
            clfRouter,
            dexSwap,
            conceroBridge,
            pool,
            infraProxy,
            chainIndex,
            messengers
        );

        _setProxyImplementation(
            address(baseOrchestratorProxy),
            address(baseOrchestratorImplementation)
        );

        _setDstInfraContractsForInfra(
            address(baseOrchestratorProxy),
            arbitrumChainSelector,
            arbitrumOrchestratorProxy
        );

        _setDstPoolForInfra(
            address(baseOrchestratorProxy),
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            arbitrumChildProxy
        );
    }

    function test_calculate_integrator_fee(uint256 bridgeAmountBase) public {
        vm.assume(bridgeAmountBase > 1);
        vm.assume(bridgeAmountBase < 100000);

        uint256 integratorFeeBase = 3;
        uint256 bridgeAmount = bridgeAmountBase * 1e18;
        uint256 integratorFeeBps = integratorFeeBase * 10; // 0.3%

        uint256 fee = InfraOrchestratorWrapper(payable(baseOrchestratorProxy))
            .calculateIntegratorFee(integratorFeeBps, bridgeAmount);

        uint256 expectedFee = ((bridgeAmount * integratorFeeBase) / 10) / 100;

        assertEq(fee, expectedFee);
    }

    function test_collect_and_withdraw_integrator_fee(uint256 bridgeAmountBase) public {
        vm.assume(bridgeAmountBase > 1);
        vm.assume(bridgeAmountBase < 100000);

        uint256 bridgeAmount = bridgeAmountBase * 1e6;
        uint256 integratorFeeBase = 2;
        uint256 integratorFeeBps = integratorFeeBase * 10; // 0.2%
        address integrator = makeAddr("integrator1");

        // @dev step1: collect integrator fee
        IInfraOrchestrator.Integration memory integration = IInfraOrchestrator.Integration({
            integrator: integrator,
            feeBps: integratorFeeBps
        });

        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
            tokenType: IInfraStorage.CCIPToken.usdc,
            amount: bridgeAmount,
            dstChainSelector: arbitrumChainSelector,
            receiver: makeAddr("receiver1")
        });

        IDexSwap.SwapData[] memory dstSwapData = new IDexSwap.SwapData[](0);

        mintUSDC(user1, bridgeAmount);
        _approve(user1, vm.envAddress("USDC_BASE"), address(baseOrchestratorProxy), bridgeAmount);

        vm.prank(user1);
        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).bridge(
            bridgeData,
            dstSwapData,
            integration
        );

        uint256 integratorFeeCollected = InfraOrchestratorWrapper(payable(baseOrchestratorProxy))
            .getCollectedIntegratorFeeByToken(integrator, vm.envAddress("USDC_BASE"));

        assertEq(integratorFeeCollected, ((bridgeAmount * integratorFeeBase) / 10) / 100);

        // @dev step2: withdraw integrator fee
        uint256 usdcIntegratorBalanceBefore = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
            integrator
        );
        vm.prank(integrator);

        InfraOrchestratorWrapper(payable(baseOrchestratorProxy)).withdrawIntegratorFees(
            vm.envAddress("USDC_BASE")
        );

        uint256 usdcIntegratorBalanceAfter = IERC20(vm.envAddress("USDC_BASE")).balanceOf(
            integrator
        );

        assertEq(usdcIntegratorBalanceAfter, usdcIntegratorBalanceBefore + integratorFeeCollected);

        // @dev step3: check that integrator fee mapping is cleared
        integratorFeeCollected = InfraOrchestratorWrapper(payable(baseOrchestratorProxy))
            .getCollectedIntegratorFeeByToken(integrator, vm.envAddress("USDC_BASE"));

        assertEq(integratorFeeCollected, 0);
    }

    function test_tx_batching_trigger() public {}
}
