// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "./BaseTest.t.sol";
import {WithdrawTest, IERC20} from "./Withdraw.t.sol";
import {ParentPool_Wrapper, IParentPoolWrapper} from "./wrappers/ParentPool_Wrapper.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {ChildPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ChildPoolProxy.sol";

contract SetPoolsTest is WithdrawTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint64 baseChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE"));
    uint64 arbitrumChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM"));
    uint64 avalancheChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE"));
    uint64 polygonChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_POLYGON"));
    uint64 optimismChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_OPTIMISM"));

    address avalancheChildImplementation;
    address avalancheChildProxy;

    address messenger = vm.envAddress("POOL_MESSENGER_0_ADDRESS");

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        /// @notice the initial child pool is set to the arbitrum selector, with the implementation address
        WithdrawTest.setUp();

        /// @dev deploy the avalanche child pool
        (avalancheChildProxy, avalancheChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_PROXY_AVALANCHE"),
            link, // not doing crosschain right now otherwise it'd be vm.envAddress("LINK_AVALANCHE")
            vm.envAddress("CL_CCIP_ROUTER_BASE"), // vm.envAddress("CL_CCIP_ROUTER_AVALANCHE")
            usdc // not doing crosschain right now otherwise it'd be vm.envAddress("USDC_AVALANCHE")
        );
    }

    /*//////////////////////////////////////////////////////////////
                               SET POOLS
    //////////////////////////////////////////////////////////////*/
    function test_setPools_success_withdrawRequest() public {
        /// @dev deposit
        _startAndCompleteDeposit(user1, DEPOSIT_AMOUNT_USDC, INITIAL_DIRECT_DEPOSIT);

        /// @dev cache number of childs before setting
        uint256 childsBefore = IParentPoolWrapper(address(parentPoolProxy)).getNumberOfChildPools();

        /// @dev set new child in old child
        vm.prank(deployer);
        (bool childSetSuccess,) = address(arbitrumChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", avalancheChainSelector, avalancheChildProxy)
        );
        require(childSetSuccess, "childProxy.setPools with avalancheChild failed");

        /// @dev set new child pool
        vm.prank(deployer);
        (bool parentSetSuccess,) = address(parentPoolProxy).call(
            abi.encodeWithSignature("setPools(uint64,address,bool)", avalancheChainSelector, avalancheChildProxy, true)
        );
        require(parentSetSuccess, "setPools with avalancheChild failed");

        /// @dev make sure the number of childs increased
        uint256 childsAfter = IParentPoolWrapper(address(parentPoolProxy)).getNumberOfChildPools();
        assertEq(childsAfter, childsBefore + 1);

        /// @dev get the number of pools: child(s) + parent
        uint256 pools = IParentPoolWrapper(address(parentPoolProxy)).getNumberOfChildPools() + 1;
        /// @dev get the lpToken supply
        uint256 lpSupplyBeforeWithdrawRequest = IERC20(address(lpToken)).totalSupply();

        /// @dev startWithdrawal and fulfillRequest for user1
        uint256 requestResponse = INITIAL_DIRECT_DEPOSIT + (DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC);
        _startWithdrawalAndFulfillRequest(user1, WITHDRAW_AMOUNT_LP, requestResponse);

        /// @dev get the withdrawRequest
        ParentPool_Wrapper.WithdrawRequest memory withdrawRequest =
            IParentPoolWrapper(address(parentPoolProxy)).getWithdrawRequest(_getWithdrawalId(user1));
        /// @dev calculate expected amount to withdraw
        uint256 expectedAmountToWithdraw =
            ((_calculateTotalCrossChainLiquidity(requestResponse) * WITHDRAW_AMOUNT_LP) / lpSupplyBeforeWithdrawRequest);

        /// @dev assert the liquidity from each pool is what we expect
        assertEq(withdrawRequest.liquidityRequestedFromEachPool, expectedAmountToWithdraw / pools);
    }

    function test_setPools_success_deposit_ccipSend() public {
        /// @dev startDeposit and fulfillRequest
        uint256 requestResponse = INITIAL_DIRECT_DEPOSIT + (DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC);
        bytes32 depositRequestId = _startDepositAndFulfillRequest(user1, DEPOSIT_AMOUNT_USDC, requestResponse);

        /// @dev set new child in old child
        vm.prank(deployer);
        (bool childSetSuccess,) = address(arbitrumChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", avalancheChainSelector, avalancheChildProxy)
        );
        require(childSetSuccess, "childProxy.setPools with avalancheChild failed");

        /// @dev set new child pool
        vm.prank(deployer);
        (bool parentSetSuccess,) = address(parentPoolProxy).call(
            abi.encodeWithSignature("setPools(uint64,address,bool)", avalancheChainSelector, avalancheChildProxy, true)
        );
        require(parentSetSuccess, "setPools with avalancheChild failed");

        /// @dev record logs
        vm.recordLogs();

        /// @dev completeDeposit
        _completeDeposit(user1, depositRequestId);

        /// @dev get the number of times ConceroParentPool_CCIPSent event emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 eventCount = 0;
        for (uint256 i = 0; i < entries.length; ++i) {
            if (entries[i].topics[0] == keccak256("ConceroParentPool_CCIPSent(bytes32,uint64,address,address,uint256)"))
            {
                eventCount++;
            }
        }

        /// @dev assert ConceroParentPool_CCIPSent is emitted for each child
        assertEq(eventCount, IParentPoolWrapper(address(parentPoolProxy)).getNumberOfChildPools());

        /// @dev find and assert the chain selectors are what we expect
        uint256 eventIndex = 0;
        for (uint256 i = 0; i < entries.length; ++i) {
            if (entries[i].topics[0] == keccak256("ConceroParentPool_CCIPSent(bytes32,uint64,address,address,uint256)"))
            {
                uint64 destinationChainSelector;
                (destinationChainSelector) = abi.decode(entries[i].data, (uint64));

                if (eventIndex == 0) {
                    assertEq(destinationChainSelector, arbitrumChainSelector);
                } else if (eventIndex == 1) {
                    assertEq(destinationChainSelector, avalancheChainSelector);
                }
                eventIndex++;
            }
        }
    }

    function test_setPools_reverts_if_pool_added_for_existing_selector() public {
        address attemptedAddress = makeAddr("attemptedAddress");

        /// @dev expect revert because we are passing the same chainSelector that was used in the initial setUp
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("ConceroParentPool_InvalidAddress()"));
        address(parentPoolProxy).call(
            abi.encodeWithSignature("setPools(uint64,address,bool)", arbitrumChainSelector, attemptedAddress, true)
        );
    }

    /*//////////////////////////////////////////////////////////////
                          DISTRIBUTE LIQUIDITY
    //////////////////////////////////////////////////////////////*/
    function test_distributeLiquidity() public {
        /// @dev deposit
        _startAndCompleteDeposit(user1, DEPOSIT_AMOUNT_USDC, INITIAL_DIRECT_DEPOSIT);

        /// @dev set new child in old child
        vm.startPrank(deployer);
        (bool success1,) = address(arbitrumChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", avalancheChainSelector, avalancheChildProxy)
        );
        require(success1, "arbitrumChildProxy.setPools with avalancheChainSelector failed");

        /// @dev set old pool and parent pool in the new pool
        (bool success2,) = address(avalancheChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", arbitrumChainSelector, arbitrumChildProxy)
        );
        require(success2, "avalancheChildProxy.setPools with arbitrumChainSelector failed");
        /// @notice using the optimismChainSelector instead of base here as we are testing on fork of base
        /// and therefore the base ccipRouter wont send to itself
        (bool success3,) = address(avalancheChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", optimismChainSelector, parentPoolProxy)
        );
        require(success3, "avalancheChildProxy.setPools with baseChainSelector failed");

        vm.recordLogs();

        /// @dev set new child pool
        (bool success4,) = address(parentPoolProxy).call(
            abi.encodeWithSignature("setPools(uint64,address,bool)", avalancheChainSelector, avalancheChildProxy, true)
        );
        require(success4, "setPools with avalancheChild failed");
        vm.stopPrank();

        /// @dev get the distributeLiquidityRequestId
        bytes32 distributeLiquidityRequestId;
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; ++i) {
            if (entries[i].topics[0] == keccak256("RequestSent(bytes32)")) {
                distributeLiquidityRequestId = entries[i].topics[1];
                break;
            }
        }

        uint256 totalLiquidity = DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC;
        uint256 initialAmountPerPool = totalLiquidity / 2;
        uint256 distributedAmountPerPool = totalLiquidity / 3;
        uint256 amountToSend = (initialAmountPerPool - distributedAmountPerPool) / 2;
        deal(link, arbitrumChildProxy, CCIP_FEES);
        deal(usdc, arbitrumChildProxy, initialAmountPerPool);

        /// @dev distribute liquidity in old child (prank messenger)
        vm.prank(messenger);
        (bool distributeSuccess,) = address(arbitrumChildProxy).call(
            abi.encodeWithSignature(
                "distributeLiquidity(uint64,uint256,bytes32)",
                avalancheChainSelector,
                amountToSend,
                distributeLiquidityRequestId
            )
        );
        require(distributeSuccess, "distributeLiquidity call failed");
    }

    /*//////////////////////////////////////////////////////////////
                      REMOVE POOLS/LIQUIDATE POOL
    //////////////////////////////////////////////////////////////*/
    function test_removePools_success() public {
        /// @dev set new child in old child
        vm.startPrank(deployer);
        (bool success1,) = address(arbitrumChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", avalancheChainSelector, avalancheChildProxy)
        );
        require(success1, "arbitrumChildProxy.setPools with avalancheChainSelector failed");

        /// @dev set old pool and parent pool in the new pool
        (bool success2,) = address(avalancheChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", arbitrumChainSelector, arbitrumChildProxy)
        );
        require(success2, "avalancheChildProxy.setPools with arbitrumChainSelector failed");
        /// @notice using the optimismChainSelector instead of base here as we are testing on fork of base
        /// and therefore the base ccipRouter wont send to itself
        (bool success3,) = address(avalancheChildProxy).call(
            abi.encodeWithSignature("setPools(uint64,address)", optimismChainSelector, parentPoolProxy)
        );
        require(success3, "avalancheChildProxy.setPools with baseChainSelector failed");

        /// @dev set new child pool
        (bool success4,) = address(parentPoolProxy).call(
            abi.encodeWithSignature("setPools(uint64,address,bool)", avalancheChainSelector, avalancheChildProxy, true)
        );
        require(success4, "setPools with avalancheChild failed");
        vm.stopPrank();

        /// @dev deposit
        _startAndCompleteDeposit(user1, DEPOSIT_AMOUNT_USDC, INITIAL_DIRECT_DEPOSIT);
        uint256 amountPerPool = (DEPOSIT_AMOUNT_USDC - DEPOSIT_FEE_USDC) / 3;
        deal(usdc, address(avalancheChildProxy), amountPerPool);
        deal(link, address(avalancheChildProxy), CCIP_FEES);

        /// @dev remove previously set child pool (avalanche) from original child (arbitrum)
        vm.prank(deployer);
        (bool childRemoveSuccess,) =
            address(arbitrumChildProxy).call(abi.encodeWithSignature("removePools(uint64)", avalancheChainSelector));
        require(childRemoveSuccess, "childProxy.removePools with avalancheChild failed");

        /// @dev record logs
        vm.recordLogs();
        /// @dev remove previously set child pool
        vm.prank(deployer);
        (bool removeSuccess,) =
            address(parentPoolProxy).call(abi.encodeWithSignature("removePools(uint64)", avalancheChainSelector));
        require(removeSuccess, "removePools with avalancheChild failed");

        /// @dev get the distributeLiquidityRequestId
        bytes32 distributeLiquidityRequestId;
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; ++i) {
            if (entries[i].topics[0] == keccak256("RequestSent(bytes32)")) {
                distributeLiquidityRequestId = entries[i].topics[1];
                break;
            }
        }

        /// @dev record logs again
        vm.recordLogs();

        /// @dev mock messenger to call liquidatePool
        vm.prank(messenger);
        (bool liquidateSuccess,) = address(avalancheChildProxy).call(
            abi.encodeWithSignature("liquidatePool(bytes32)", distributeLiquidityRequestId)
        );
        require(liquidateSuccess, "liquidatePool call failed");

        /// @dev read logs and assert USDC transfers from the liquidated child pool are the correct amount of value and txs
        Vm.Log[] memory postLiquidationEntries = vm.getRecordedLogs();
        uint256 expectedAmount = (amountPerPool / 2) - (amountPerPool % 2);
        uint256 poolDistributions;

        for (uint256 i = 0; i < postLiquidationEntries.length; ++i) {
            if (
                postLiquidationEntries[i].emitter == usdc
                    && postLiquidationEntries[i].topics[0] == keccak256("Transfer(address,address,uint256)")
            ) {
                address from = address(uint160(uint256(postLiquidationEntries[i].topics[1])));
                address to = address(uint160(uint256(postLiquidationEntries[i].topics[2])));
                uint256 value = abi.decode(postLiquidationEntries[i].data, (uint256));

                if (from == avalancheChildProxy) {
                    assertEq(value, expectedAmount);
                    poolDistributions++;
                }
            }
        }

        uint256 pools = IParentPoolWrapper(address(parentPoolProxy)).getNumberOfChildPools() + 1;
        assertEq(poolDistributions, pools);
    }
}
