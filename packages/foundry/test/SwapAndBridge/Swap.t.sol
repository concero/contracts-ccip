// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "../BaseTest.t.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OrchestratorWrapper} from "./wrappers/OrchestratorWrapper.sol";

contract SwapTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant FROM_AMOUNT = 1_000_000_000; // 1k usdc
    uint256 internal constant TO_AMOUNT = 95 * 1e18; // 95 LINK
    uint256 internal constant TO_AMOUNT_MIN = 75 * 1e18; // 75 LINK
    address internal constant WRAPPED_NATIVE_BASE = 0x4200000000000000000000000000000000000006;
    address internal constant UNI_V3_ROUTER_BASE = 0x2626664c2603336E57B271c5C0b26F421741e481;
    uint256 internal constant WRAP_AMOUNT = 1 ether; // 1 Ether to wrap

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
    }

    /*//////////////////////////////////////////////////////////////
                                  SWAP
    //////////////////////////////////////////////////////////////*/
    function test_integratorFees_swap() public {
        deal(user1, WRAP_AMOUNT);
        _wrapNativeSwap(user1, WRAP_AMOUNT, integrator, INTEGRATOR_FEE_PERCENT);

        (, bytes memory retData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getIntegratorFees(address,address)", integrator, address(0))
        );

        uint256 integratorFeesEarned = abi.decode(retData, (uint256));
        uint256 expectedFeesEarned = (WRAP_AMOUNT * INTEGRATOR_FEE_PERCENT) /
            INTEGRATOR_FEE_DIVISOR;

        assertEq(expectedFeesEarned, integratorFeesEarned);

        /// @dev this is irrelevant for testing integratorFees,
        // but demonstrates the end result of a IDexSwap.DexType.WrapNative swap
        uint256 balance = IERC20(WRAPPED_NATIVE_BASE).balanceOf(user1);
        console.log("balance:", balance);
    }

    function test_integratorFees_total_earned() public {
        address integrator2 = makeAddr("integrator2");
        deal(user1, WRAP_AMOUNT * 2);
        _wrapNativeSwap(user1, WRAP_AMOUNT, integrator, INTEGRATOR_FEE_PERCENT);
        _wrapNativeSwap(user1, WRAP_AMOUNT, integrator2, MAX_INTEGRATOR_FEE_PERCENT * 2);

        (, bytes memory retData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getTotalIntegratorFeesPerToken(address)", address(0))
        );
        uint256 totalIntegratorFeesEarned = abi.decode(retData, (uint256));
        uint256 firstIntegratorFees = (WRAP_AMOUNT * INTEGRATOR_FEE_PERCENT) /
            INTEGRATOR_FEE_DIVISOR;
        uint256 secondIntegratorFees = (WRAP_AMOUNT * MAX_INTEGRATOR_FEE_PERCENT) /
            INTEGRATOR_FEE_DIVISOR;
        uint256 expectedTotalFeesEarned = firstIntegratorFees + secondIntegratorFees;
        assertEq(totalIntegratorFeesEarned, expectedTotalFeesEarned);
    }

    function test_integratorFees_withdraw_native() public {
        _setStorageVars();
        deal(user1, WRAP_AMOUNT);
        _wrapNativeSwap(user1, WRAP_AMOUNT, integrator, INTEGRATOR_FEE_PERCENT);

        uint256 balanceBefore = integrator.balance;

        vm.prank(integrator);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("withdrawIntegratorFees(address)", address(0))
        );

        uint256 balanceAfter = integrator.balance;

        uint256 expectedFeesEarned = (WRAP_AMOUNT * INTEGRATOR_FEE_PERCENT) /
            INTEGRATOR_FEE_DIVISOR;

        assertEq(expectedFeesEarned, balanceAfter - balanceBefore);
    }

    function test_integratorFees_cant_be_withdrawn_by_admin() public {
        _setStorageVars();
        deal(user1, WRAP_AMOUNT);
        _wrapNativeSwap(user1, WRAP_AMOUNT, integrator, INTEGRATOR_FEE_PERCENT);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("Orchestrator_InvalidAmount()"));
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "withdraw(address,address,uint256)",
                deployer,
                address(0),
                WRAP_AMOUNT
            )
        );
    }

    function _wrapNativeSwap(
        address _caller,
        uint256 _amount,
        address _integrator,
        uint256 _integratorPercent
    ) internal {
        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        IDexSwap.SwapData memory wrapSwap = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.WrapNative,
            fromToken: address(0),
            fromAmount: _amount,
            toToken: WRAPPED_NATIVE_BASE,
            toAmount: _amount,
            toAmountMin: _amount,
            dexData: ""
        });
        swapData[0] = wrapSwap;

        vm.prank(_caller);
        (bool success, ) = address(baseOrchestratorProxy).call{value: _amount}(
            abi.encodeWithSignature(
                "swap((uint8,address,uint256,address,uint256,uint256,bytes)[],address,address,uint256)",
                swapData,
                _caller,
                _integrator,
                _integratorPercent
            )
        );
        require(success, "wrap native call failed");
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _allowUniV3Router() internal {
        vm.prank(deployer);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("setDexRouterAddress(address,uint256)", UNI_V3_ROUTER_BASE, 1)
        );
        /// @dev assert it is set correctly
        (, bytes memory returnData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("s_routerAllowed(address)", UNI_V3_ROUTER_BASE)
        );
        uint256 returnedValue = abi.decode(returnData, (uint256));
        assertEq(returnedValue, 1);
    }

    /*//////////////////////////////////////////////////////////////
                             UNISWAP STUFF
    //////////////////////////////////////////////////////////////*/
    // {
    //     address routerAddress = UNI_V3_ROUTER_BASE;
    //     uint24 fee = 3000;
    //     uint160 sqrtPriceLimitX96 = type(uint160).max;
    //     uint256 deadline = block.timestamp + 3600;
    //     bytes memory dexData = abi.encode(routerAddress, fee, sqrtPriceLimitX96, deadline);

    //     IDexSwap.SwapData[1] memory swapData;
    //     IDexSwap.SwapData memory swap1 = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.UniswapV3Single,
    //         fromToken: usdc,
    //         fromAmount: FROM_AMOUNT,
    //         toToken: link,
    //         toAmount: TO_AMOUNT,
    //         toAmountMin: TO_AMOUNT_MIN,
    //         dexData: dexData
    //     });
    //     swapData[0] = swap1;
    // }

    // function test_swap() public {
    //     _allowUniV3Router();
    //     deal(usdc, user1, FROM_AMOUNT);
    //     vm.prank(user1);
    //     IERC20(usdc).approve(address(baseOrchestratorProxy), type(uint256).max);

    //     _swap(user1, integrator, INTEGRATOR_FEE_PERCENT);
    // }

    // function _swap(address _caller, address _integrator, uint256 _integratorFee) internal {
    //     console.log("inside test _swap");

    //     address routerAddress = UNI_V3_ROUTER_BASE;
    //     uint24 fee = 3000;
    //     uint160 sqrtPriceLimitX96 = type(uint160).max;
    //     uint256 deadline = block.timestamp + 3600;
    //     bytes memory dexData = abi.encode(routerAddress, fee, sqrtPriceLimitX96, deadline);

    //     IDexSwap.SwapData[1] memory swapData;
    //     IDexSwap.SwapData memory swap1 = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.UniswapV3Single,
    //         fromToken: usdc,
    //         fromAmount: FROM_AMOUNT,
    //         toToken: link,
    //         toAmount: TO_AMOUNT,
    //         toAmountMin: TO_AMOUNT_MIN,
    //         dexData: dexData
    //     });
    //     swapData[0] = swap1;

    //     vm.prank(user1);
    //     (bool success, ) = address(baseOrchestratorProxy).call(
    //         abi.encodeWithSignature(
    //             "swap((uint8,address,uint256,address,uint256,uint256,bytes)[],address,address,uint256)",
    //             swapData,
    //             msg.sender,
    //             _integrator,
    //             _integratorFee
    //         )
    //     );
    //     require(success, "swap call failed");
    // }
}
