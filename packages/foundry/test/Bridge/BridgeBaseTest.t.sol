//// SPDX-License-Identifier: MIT
//
//pragma solidity 0.8.20;
//
//import {BaseTest, console} from "../utils/BaseTest.t.sol";
//import {InfraOrchestratorWrapper} from "./wrappers/InfraOrchestratorWrapper.sol";
//import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
//import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//
//contract BridgeBaseTest is BaseTest {
//    /*//////////////////////////////////////////////////////////////
//                               VARIABLES
//    //////////////////////////////////////////////////////////////*/
//    address internal constant WRAPPED_NATIVE_BASE = 0x4200000000000000000000000000000000000006;
//    address internal constant UNI_V3_ROUTER_BASE = 0x2626664c2603336E57B271c5C0b26F421741e481;
//    address constant UNI_V3_ROUTER_AVALANCHE = 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;
//
//    /*//////////////////////////////////////////////////////////////
//                                 SETUP
//    //////////////////////////////////////////////////////////////*/
//    function setUp() public virtual override {
//        vm.selectFork(forkId);
//        _deployOrchestratorProxy();
//        _deployDexSwap();
//        deployBridgesInfra();
//        deployPoolsInfra();
//
//        vm.prank(deployer);
//        baseOrchestratorImplementation = new InfraOrchestratorWrapper(
//            vm.envAddress("CLF_ROUTER_BASE"),
//            address(dexSwap),
//            address(baseBridgeImplementation),
//            address(parentPoolProxy),
//            address(baseOrchestratorProxy),
//            1, // IInfraStorage.Chain.base
//            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
//        );
//        _setProxyImplementation(
//            address(baseOrchestratorProxy),
//            address(baseOrchestratorImplementation)
//        );
//
//        /// @dev set destination chain selector and contracts on Base
//        _setDstSelectorAndPool(arbitrumChainSelector, arbitrumChildProxy);
//        _setDstSelectorAndBridge(arbitrumChainSelector, address(1)); // arbitrumOrchestratorProxy
//        _setDstSelectorAndPool(avalancheChainSelector, address(2)); // avalancheChildProxy
//        _setDstSelectorAndBridge(avalancheChainSelector, address(3)); // avalancheOrchestratorProxy
//
//        _allowUniV3Router();
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                                UTILITY
//    //////////////////////////////////////////////////////////////*/
//    function _startBridge(address _caller, uint256 _amount, uint64 _dstChainSelector) internal {
//        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
//            tokenType: IInfraStorage.CCIPToken.usdc,
//            amount: _amount,
//            dstChainSelector: _dstChainSelector,
//            receiver: msg.sender
//        });
//        IDexSwap.SwapData[] memory dstSwapData;
//
//        vm.prank(_caller);
//        (bool success, ) = address(baseOrchestratorProxy).call(
//            abi.encodeWithSignature(
//                "bridge((uint8,uint256,uint64,address),(uint8,address,uint256,address,uint256,uint256,bytes)[])",
//                bridgeData,
//                dstSwapData
//            )
//        );
//        require(success, "bridge call failed");
//    }
//
//    function _startBridgeWithDstSwapData(
//        address _caller,
//        uint256 _amount,
//        uint64 _dstChainSelector,
//        IDexSwap.SwapData[] memory _dstSwapData
//    ) internal {
//        IInfraStorage.BridgeData memory bridgeData = IInfraStorage.BridgeData({
//            tokenType: IInfraStorage.CCIPToken.usdc,
//            amount: _amount,
//            dstChainSelector: _dstChainSelector,
//            receiver: msg.sender
//        });
//
//        vm.prank(_caller);
//        (bool success, ) = address(baseOrchestratorProxy).call(
//            abi.encodeWithSignature(
//                "bridge((uint8,uint256,uint64,address),(uint8,address,uint256,address,uint256,uint256,bytes)[])",
//                bridgeData,
//                _dstSwapData
//            )
//        );
//        require(success, "bridge call failed");
//    }
//
//    function _dealUsdcAndApprove(address _caller, uint256 _usdcAmount) internal {
//        deal(usdc, _caller, _usdcAmount);
//        vm.prank(_caller);
//        IERC20(usdc).approve(address(baseOrchestratorProxy), type(uint256).max);
//    }
//
//    function _dealLinkToProxy(uint256 _amount) internal {
//        deal(link, address(baseOrchestratorProxy), _amount);
//    }
//
//    function _allowUniV3Router() internal {
//        vm.prank(deployer);
//        (bool success, ) = address(baseOrchestratorProxy).call(
//            abi.encodeWithSignature("setDexRouterAddress(address,uint256)", UNI_V3_ROUTER_BASE, 1)
//        );
//        /// @dev assert it is set correctly
//        (, bytes memory returnData) = address(baseOrchestratorProxy).call(
//            abi.encodeWithSignature("s_routerAllowed(address)", UNI_V3_ROUTER_BASE)
//        );
//        uint256 returnedValue = abi.decode(returnData, (uint256));
//        assertEq(returnedValue, 1);
//    }
//}
