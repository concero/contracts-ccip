// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {BaseTest, console, Vm} from "../utils/BaseTest.t.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Internal} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Internal.sol";
import {InfraOrchestratorWrapper} from "./wrappers/InfraOrchestratorWrapper.sol";

contract StartBridge is BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant LIQUIDITY_PROVIDED = 100_000_000_000;
    uint256 internal constant USER_FUNDS = 1_000_000_000;
    uint256 internal constant MIN_BRIDGE_AMOUNT = 100_000_000;
    uint256 internal constant MAX_BRIDGE_AMOUNT = 100_000_000_000;
    uint256 internal constant BATCHED_TX_THRESHOLD = 5_000_000_000; // 5,000 USDC
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;
    uint64 private constant HALF_DST_GAS = 600_000;
    uint256 internal constant STANDARD_TOKEN_DECIMALS = 1 ether;

    address[] internal users;

    /// @dev using this struct to get around stack too deep errors for ccipFee calculation test
    struct FeeData {
        uint256 totalFeeInUsdc;
        uint256 functionsFeeInUsdc;
        uint256 conceroFee;
        uint256 messengerGasFeeInUsdc;
    }

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        vm.selectFork(forkId);
        _deployOrchestratorProxy();
        deployBridgesInfra();
        deployPoolsInfra();

        vm.prank(deployer);
        baseOrchestratorImplementation = new InfraOrchestratorWrapper(
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CONCERO_DEX_SWAP_BASE"),
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
        _setChildPoolForInfra(address(baseOrchestratorProxy), arbitrumChainSelector, address(0x1));
        _setDstInfraContractsForInfra(
            address(baseOrchestratorProxy),
            arbitrumChainSelector,
            address(0x15)
        );
        _setChildPoolForInfra(address(baseOrchestratorProxy), avalancheChainSelector, address(0x2));
        _setDstInfraContractsForInfra(
            address(baseOrchestratorProxy),
            avalancheChainSelector,
            address(0x25)
        );

        deal(vm.envAddress("LINK_BASE"), address(baseOrchestratorProxy), LINK_INIT_BALANCE);

        users.push(user1);
        users.push(user2);
        users.push(makeAddr("user3"));
        users.push(makeAddr("user4"));
        users.push(makeAddr("user5"));
    }

    /*//////////////////////////////////////////////////////////////
                              START BRIDGE
    //////////////////////////////////////////////////////////////*/
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
        baseBridgeImplementation.bridge(bridgeData, dstSwapData);
    }

    function _startBridge(address _caller, uint256 _amount, uint64 _dstChainSelector) internal {
        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
            tokenType: IInfraStorage.CCIPToken.usdc,
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

    function _setStorageVars() internal {
        /// @dev used cast call on the current mainnet infrastructure to get values
        // cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "s_lastGasPrices(uint64)" 4949039107694359620 --rpc-url https://mainnet.base.org
        // 10000000
        // cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "s_lastGasPrices(uint64)" 15971525489660198786 --rpc-url https://mainnet.base.org
        // 7426472
        /// @dev set the lastGasPrices
        (bool s1, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "setLastGasPrices(uint64,uint256)",
                arbitrumChainSelector,
                10000000
            )
        );
        require(s1, "setLastGasPrices failed");
        (bool s2, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("setLastGasPrices(uint64,uint256)", baseChainSelector, 7426472)
        );
        require(s2, "setLastGasPrices failed");
        // cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "s_latestNativeUsdcRate()" --rpc-url https://mainnet.base.org
        // 2648148683069102878667
        (bool s3, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("setLatestNativeUsdcRate(uint256)", 2648148683069102878667)
        );
        require(s3, "setLatestNativeUsdcRate failed");

        // cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "clfPremiumFees(uint64)" 4949039107694359620 --rpc-url https://mainnet.base.org
        // 20000000000000000
        vm.prank(deployer);
        (bool s4, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "setClfPremiumFees(uint64,uint256)",
                arbitrumChainSelector,
                20000000000000000
            )
        );
        require(s4, "setClfPremiumFees failed");

        // cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "clfPremiumFees(uint64)" 15971525489660198786 --rpc-url https://mainnet.base.org
        // 60000000000000000
        vm.prank(deployer);
        (bool s5, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "setClfPremiumFees(uint64,uint256)",
                baseChainSelector,
                60000000000000000
            )
        );
        require(s5, "setClfPremiumFees failed");

        /// @dev set the last CCIP fee in LINK
        (bool s6, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "setLastCCIPFeeInLink(uint64,uint256)",
                arbitrumChainSelector,
                1e18
            )
        );
        require(s6, "setLastCCIPFeeInLink failed");

        // cast call 0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d "s_latestLinkUsdcRate()" --rpc-url https://mainnet.base.org
        // 11491601885989307360
        (bool s7, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("setLatestLinkUsdcRate(uint256)", 11491601885989307360)
        );
        require(s7, "setLatestLinkUsdcRate failed");
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

    function _getFeeData(uint256 _amount) internal returns (FeeData memory) {
        FeeData memory feeData;

        /// @dev get the totalFeeInUsdc
        (, bytes memory totalFeeInUsdcData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "getSrcTotalFeeInUSDCDelegateCall(uint64,uint256)",
                arbitrumChainSelector,
                _amount
            )
        );
        feeData.totalFeeInUsdc = abi.decode(totalFeeInUsdcData, (uint256));

        /// @dev get the functionsFeeInUsdc
        (, bytes memory functionsFeeInUsdcData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "getFunctionsFeeInUsdcDelegateCall(uint64)",
                arbitrumChainSelector
            )
        );
        feeData.functionsFeeInUsdc = abi.decode(functionsFeeInUsdcData, (uint256));

        /// @dev calculate the conceroFee
        feeData.conceroFee = _amount / CONCERO_FEE_FACTOR;

        /// @dev get the messengerGasFeeInUsdc
        feeData.messengerGasFeeInUsdc = _getMessengerGasFeeInUsdc();

        return feeData;
    }

    function _getMessengerGasFeeInUsdc() internal returns (uint256) {
        /// @dev get the lastGasPrices
        (, bytes memory dstGasPriceData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("s_lastGasPrices(uint64)", arbitrumChainSelector)
        );
        uint256 dstGasPrice = abi.decode(dstGasPriceData, (uint256));

        (, bytes memory srcGasPriceData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("s_lastGasPrices(uint64)", baseChainSelector)
        );
        uint256 srcGasPrice = abi.decode(srcGasPriceData, (uint256));

        uint256 messengerDstGasInNative = HALF_DST_GAS * dstGasPrice;
        uint256 messengerSrcGasInNative = HALF_DST_GAS * srcGasPrice;

        /// @dev get the latestNativeUsdcRate
        (, bytes memory latestNativeUsdcRateData) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("s_latestNativeUsdcRate()")
        );
        uint256 latestNativeUsdcRate = abi.decode(latestNativeUsdcRateData, (uint256));

        return
            ((messengerDstGasInNative + messengerSrcGasInNative) * latestNativeUsdcRate) /
            STANDARD_TOKEN_DECIMALS;
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
