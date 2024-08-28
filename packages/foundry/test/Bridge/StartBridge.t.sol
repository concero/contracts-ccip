// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "../BaseTest.t.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {IStorage} from "contracts/Interfaces/IStorage.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/transparentProxy/TransparentUpgradeableProxy.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Internal} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Internal.sol";
import {OrchestratorWrapper} from "./wrappers/OrchestratorWrapper.sol";

contract StartBridgeTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant LIQUIDITY_PROVIDED = 100_000_000_000;
    uint256 internal constant USER_FUNDS = 1_000_000_000;
    uint256 internal constant MIN_BRIDGE_AMOUNT = 100_000_000;
    uint256 internal constant MAX_BRIDGE_AMOUNT = 10_000_000_000;
    uint256 internal constant ETH_BALANCE = 10 * 1e18;

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
        deployBridgesInfra();
        deployPoolsInfra();

        vm.prank(deployer);
        baseOrchestratorImplementation = new OrchestratorWrapper(
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CONCERO_DEX_SWAP_BASE"),
            address(baseBridgeImplementation),
            address(parentPoolProxy),
            address(baseOrchestratorProxy),
            1, // IStorage.Chain.base
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
    /// @notice this test will fail on this branch. this will only succeed on feat/ccip-transaction-batching branch
    function test_startBridge_success() public {
        _dealUserFundsAndApprove();

        uint256 txIdCount;

        vm.recordLogs();
        for (uint256 i; i < users.length; ++i) {
            _startBridge(users[i], USER_FUNDS, arbitrumChainSelector);

            (, bytes memory updatedReturnData) = address(baseOrchestratorProxy).call(
                abi.encodeWithSignature("getBridgeTxIdsPerChain(uint64)", arbitrumChainSelector)
            );
            bytes32[] memory updatedBatchedTxId = abi.decode(updatedReturnData, (bytes32[]));
            uint256 updatedTxIdLength = updatedBatchedTxId.length;

            if (updatedTxIdLength > txIdCount) txIdCount++;
        }

        /// @dev assert s_pendingCCIPTransactionsByDstChain[_dstChainSelector] gets updated
        assertEq(txIdCount, 5 - 1); // USERS - FINAL_SENDING_USER

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
        bytes32[] memory deletedBatchedTxIds = abi.decode(updatedReturnData, (bytes32[]));
        assertEq(deletedBatchedTxIds.length, 0);

        /// @dev assert lastCcipFeeInLink is correct
        (, bytes memory retData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("getLastCCIPFeeInLink(uint64)", arbitrumChainSelector)
        );
        uint256 actualAmountLastCcipFee = abi.decode(retData, (uint256));
        assertEq(expectedLastCcipFee, actualAmountLastCcipFee);

        /// @dev assert that the EVM2EVMOnRamp.CCIPSendRequested event was emitted only once
        assertEq(eventCount, 1);
        /// @dev assert that the amount sent in the single tx was equal to the 5 users' funds
        assertEq(amountSent, 5 * USER_FUNDS);
    }

    function test_startBridge_reverts_if_not_proxy(address _caller, uint256 _amount) public {
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: USER_FUNDS,
            dstChainSelector: arbitrumChainSelector,
            receiver: msg.sender
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
        baseBridgeImplementation.startBridge(bridgeData, dstSwapData, address(0));
    }

    function test_startBridge_CCIP_native_fees() public {
        // Arrange
        vm.deal(address(baseOrchestratorProxy), ETH_BALANCE);
        _dealUserFundsAndApprove();

        address feeToken;
        uint256 feeTokenAmount;

        // Act
        vm.recordLogs();
        _startBridge(user1, USER_FUNDS, arbitrumChainSelector);

        // Assert
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

    function _startBridge(address _caller, uint256 _amount, uint64 _dstChainSelector) internal {
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: _amount,
            dstChainSelector: _dstChainSelector,
            receiver: msg.sender
        });
        IDexSwap.SwapData[] memory dstSwapData;

        vm.prank(_caller);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "bridge((uint8,uint256,uint64,address),(uint8,address,uint256,address,uint256,uint256,bytes)[])",
                bridgeData,
                dstSwapData
            )
        );
        require(success, "bridge call failed");
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
            deal(usdc, users[i], USER_FUNDS);
            vm.prank(users[i]);
            IERC20(usdc).approve(address(baseOrchestratorProxy), USER_FUNDS);
        }
    }
}
