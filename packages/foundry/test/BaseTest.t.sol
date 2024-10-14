// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ParentPool} from "contracts/ParentPool.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {ChildPool} from "contracts/ChildPool.sol";
import {LPToken} from "contracts/LPToken.sol";
import {CCIPLocalSimulator} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPLocalSimulatorFork} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "../../../lib/chainlink-local/src/ccip/Register.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
import {ParentPoolCLFCLA} from "contracts/ParentPoolCLFCLA.sol";
import {DexSwap} from "contracts/DexSwap.sol";

contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant STANDARD_TOKEN_DECIMALS = 1 ether;
    uint256 internal constant CCIP_FEES = 100 * 1e18;
    uint256 internal constant INTEGRATOR_FEE_DIVISOR = 100;
    uint256 internal constant MAX_INTEGRATOR_FEE_PERCENT = 25;
    uint256 internal constant INTEGRATOR_FEE_PERCENT = 10;
    uint256 internal constant USER_FUNDS = 1_000_000_000;
    uint64 private constant HALF_DST_GAS = 600_000;
    uint16 internal constant CONCERO_FEE_FACTOR = 1000;

    ParentPool public parentPoolImplementation;
    TransparentUpgradeableProxy public parentPoolProxy;
    LPToken public lpToken;
    FunctionsSubscriptions public functionsSubscriptions;
    CCIPLocalSimulator public ccipLocalSimulator;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    ParentPoolCLFCLA public parentPoolClfCla;
    DexSwap public dexSwap;
    DexSwap public avalancheDexSwap;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address messenger = vm.envAddress("POOL_MESSENGER_0_ADDRESS");

    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");
    uint256 internal forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
    uint256 internal avalancheFork = vm.createFork(vm.envString("LOCAL_AVALANCHE_FORK_RPC_URL"));
    address internal usdc = vm.envAddress("USDC_BASE");
    address internal link = vm.envAddress("LINK_BASE");
    uint64 internal baseChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE"));
    uint64 internal optimismChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_OPTIMISM"));
    uint64 internal arbitrumChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM"));
    uint64 internal avalancheChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE"));

    address arbitrumChildProxy;
    address arbitrumChildImplementation;
    address avalancheChildProxy;
    address avalancheChildImplementation;

    ConceroBridge internal baseBridgeImplementation;
    ConceroBridge internal arbitrumBridgeImplementation;
    ConceroBridge internal avalancheBridgeImplementation;

    TransparentUpgradeableProxy internal baseOrchestratorProxy;
    InfraOrchestrator internal baseOrchestratorImplementation;
    TransparentUpgradeableProxy internal arbitrumOrchestratorProxy;
    InfraOrchestrator internal arbitrumOrchestratorImplementation;
    TransparentUpgradeableProxy internal avalancheOrchestratorProxy;
    InfraOrchestrator internal avalancheOrchestratorImplementation;

    address internal automationForwarder = makeAddr("automationForwarder");
    address internal integrator = makeAddr("integrator");

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
    function setUp() public virtual {
        vm.selectFork(forkId);

        _deployOrchestratorProxy();
        _deployDexSwap();

        deployBridgesInfra();

        deployPoolsInfra();

        _deployOrchestratorImplementation();
        _setProxyImplementation(
            address(baseOrchestratorProxy),
            address(baseOrchestratorImplementation)
        );

        /// @dev set destination chain selector and contracts on Base
        _setDstSelectorAndPool(arbitrumChainSelector, arbitrumChildProxy);
        _setDstSelectorAndBridge(arbitrumChainSelector, address(arbitrumOrchestratorProxy));
    }

    function deployPoolsInfra() public {
        deployParentPoolProxy();
        deployLpToken();
        _deployParentPoolClfCla();
        _deployParentPool();
        _setProxyImplementation(address(parentPoolProxy), address(parentPoolImplementation));

        /// @dev set initial child pool
        (arbitrumChildProxy, arbitrumChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_PROXY_ARBITRUM"),
            vm.envAddress("LINK_ARBITRUM"),
            vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_ARBITRUM"),
            optimismChainSelector, // parentPool chain selector (for testing)
            address(parentPoolProxy)
        );
        setParentPoolVars(arbitrumChainSelector, arbitrumChildProxy);

        _deployCcipLocalSimulation();
        addFunctionsConsumer(
            vm.envAddress("CLF_ROUTER_BASE"),
            address(parentPoolProxy),
            uint64(vm.envUint("CLF_SUBID_BASE"))
        );
        _fundLinkParentProxy(CCIP_FEES);
    }

    function deployBridgesInfra() public {
        _deployBaseBridgeImplementation();

        _deployArbitrumBridgeImplementation();

        _deployAvalancheBridgeImplementation();

        addFunctionsConsumer(
            vm.envAddress("CLF_ROUTER_BASE"),
            address(baseOrchestratorProxy),
            uint64(vm.envUint("CLF_SUBID_BASE"))
        );
    }

    /*//////////////////////////////////////////////////////////////
                              DEPLOYMENTS
    //////////////////////////////////////////////////////////////*/
    function deployParentPoolProxy() public {
        vm.prank(proxyDeployer);
        parentPoolProxy = new TransparentUpgradeableProxy(
            vm.envAddress("CONCERO_PAUSE_BASE"),
            proxyDeployer,
            bytes("")
        );
    }

    function _deployParentPool() private {
        // Deploy the default ConceroParentPool if no custom address is provided
        vm.prank(deployer);
        parentPoolImplementation = new ParentPool(
            address(parentPoolProxy),
            address(parentPoolClfCla),
            automationForwarder,
            vm.envAddress("LINK_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            address(baseOrchestratorProxy), // vm.envAddress("CONCERO_ORCHESTRATOR_BASE")
            vm.envAddress("CLF_ROUTER_BASE"),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function _deployParentPoolClfCla() internal {
        vm.prank(deployer);
        parentPoolClfCla = new ParentPoolCLFCLA(
            address(parentPoolProxy),
            address(lpToken),
            vm.envAddress("USDC_BASE"),
            vm.envAddress("CLF_ROUTER_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            vm.envBytes32("CLF_DONID_BASE"),
            automationForwarder,
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function deployLpToken() public {
        vm.prank(deployer);
        lpToken = new LPToken(deployer, address(parentPoolProxy));
    }

    function _deployCCIPLocalSimulatorFork() internal {
        uint256 BASE_CHAIN_ID = 8453;

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        Register.NetworkDetails memory baseDetails = Register.NetworkDetails({
            chainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE")),
            routerAddress: vm.envAddress("CL_CCIP_ROUTER_BASE"),
            linkAddress: vm.envAddress("LINK_BASE"),
            wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
            ccipBnMAddress: address(0),
            ccipLnMAddress: address(0)
        });

        ccipLocalSimulatorFork.setNetworkDetails(BASE_CHAIN_ID, baseDetails);
    }

    function _deployCcipLocalSimulation() private {
        ccipLocalSimulator = new CCIPLocalSimulator();
        ccipLocalSimulator.configuration();
        ccipLocalSimulator.supportNewToken(vm.envAddress("USDC_BASE"));
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/
    function _setProxyImplementation(address _proxy, address _implementation) internal {
        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(address(_proxy)).upgradeToAndCall(_implementation, bytes(""));
    }

    /// @notice might need to update this to pass _parentPoolImplementation like above
    function setParentPoolVars(uint64 _chainSelector, address _childProxy) public {
        vm.prank(deployer);
        IParentPool(address(parentPoolProxy)).setPools(_chainSelector, _childProxy, false);

        vm.prank(deployer);
        // should probably update this from user1
        IParentPool(address(parentPoolProxy)).setConceroContractSender(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            address(user1),
            1
        );
    }

    function _setDstSelectorAndPool(uint64 _chainSelector, address _poolProxy) internal {
        vm.prank(deployer);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature("setDstConceroPool(uint64,address)", _chainSelector, _poolProxy)
        );
        require(success, "setDstConceroPool call failed");
    }

    function _setDstSelectorAndBridge(uint64 _chainSelector, address _bridgeProxy) internal {
        vm.prank(deployer);
        (bool success, ) = address(baseOrchestratorProxy).call(
            abi.encodeWithSignature(
                "setConceroContract(uint64,address)",
                _chainSelector,
                _bridgeProxy
            )
        );
        require(success, "setConceroContract call failed");
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function addFunctionsConsumer(
        address _functionsRouter,
        address _consumer,
        uint64 _subId
    ) public {
        vm.prank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions = FunctionsSubscriptions(_functionsRouter);
        functionsSubscriptions.addConsumer(_subId, _consumer);
    }

    function _fundLinkParentProxy(uint256 amount) internal {
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), amount);
    }

    function _fundFunctionsSubscription() internal {
        address linkAddress = vm.envAddress("LINK_BASE");
        LinkTokenInterface linkToken = LinkTokenInterface(vm.envAddress("LINK_BASE"));
        address router = vm.envAddress("CLF_ROUTER_BASE");
        bytes memory data = abi.encode(uint64(vm.envUint("CLF_SUBID_BASE")));

        uint256 funds = 100 * 1e18; // 100 LINK

        address subFunder = makeAddr("subFunder");
        deal(linkAddress, subFunder, funds);

        vm.prank(subFunder);
        linkToken.transferAndCall(router, funds, data);
    }

    /*//////////////////////////////////////////////////////////////
                              CHILD POOLS
    //////////////////////////////////////////////////////////////*/
    function _deployChildPoolImplementation(
        address _infraProxy,
        address _proxy,
        address _link,
        address _ccipRouter,
        address _usdc,
        address _owner,
        address[3] memory _messengers
    ) internal returns (address) {
        vm.prank(deployer);
        ChildPool childPool = new ChildPool(
            _infraProxy,
            _proxy,
            _link,
            _ccipRouter,
            _usdc,
            deployer,
            _messengers
        );

        return address(childPool);
    }

    function _deployChildPoolProxy() internal returns (address) {
        vm.prank(proxyDeployer);
        TransparentUpgradeableProxy childPoolProxy = new TransparentUpgradeableProxy(
            vm.envAddress("CONCERO_PAUSE_BASE"),
            proxyDeployer,
            bytes("")
        );
        return address(childPoolProxy);
    }

    function _deployChildPool(
        address _infraProxy,
        address _link,
        address _ccipRouter,
        address _usdc,
        uint64 _parentPoolChainSelector,
        address _parentProxy
    ) internal returns (address, address) {
        address childProxy = _deployChildPoolProxy();
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];

        address childImplementation = _deployChildPoolImplementation(
            _infraProxy,
            childProxy,
            _link,
            _ccipRouter,
            _usdc,
            deployer,
            messengers
        );

        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(childProxy).upgradeToAndCall(childImplementation, bytes(""));

        /// set the parentPool in childProxy.setPools();
        vm.prank(deployer);
        (bool success, ) = address(arbitrumChildProxy).call(
            abi.encodeWithSignature(
                "setPools(uint64,address)",
                _parentPoolChainSelector,
                _parentProxy
            )
        );
        require(success, "childProxy.setPools with parentPool failed");

        return (childProxy, childImplementation);
    }

    /*//////////////////////////////////////////////////////////////
                                BRIDGES
    //////////////////////////////////////////////////////////////*/
    function _deployBridge(
        IInfraStorage.FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers
    ) internal returns (ConceroBridge) {
        vm.prank(deployer);
        return
            new ConceroBridge(
                _variables,
                _chainSelector,
                _chainIndex,
                _link,
                _ccipRouter,
                _dexSwap,
                _pool,
                _proxy,
                _messengers
            );
    }

    function _deployBaseBridgeImplementation() internal {
        IInfraStorage.FunctionsVariables memory functionsVariables = IInfraStorage
            .FunctionsVariables({
                subscriptionId: uint64(vm.envUint("CLF_SUBID_BASE")),
                donId: vm.envBytes32("CLF_DONID_BASE"),
                functionsRouter: vm.envAddress("CLF_ROUTER_BASE")
            });
        uint64 chainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE"));
        uint256 chainIndex = 1; // IInfraStorage.Chain.base
        address link = vm.envAddress("LINK_BASE");
        address ccipRouter = vm.envAddress("CL_CCIP_ROUTER_BASE");
        address dexswap = vm.envAddress("CONCERO_DEX_SWAP_BASE");
        address pool = address(parentPoolProxy);
        address proxy = address(baseOrchestratorProxy);
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];

        baseBridgeImplementation = _deployBridge(
            functionsVariables,
            chainSelector,
            chainIndex,
            link,
            ccipRouter,
            dexswap,
            pool,
            proxy,
            messengers
        );
    }

    function _deployArbitrumBridgeImplementation() internal {
        IInfraStorage.FunctionsVariables memory functionsVariables = IInfraStorage
            .FunctionsVariables({
                subscriptionId: uint64(vm.envUint("CLF_SUBID_ARBITRUM")),
                donId: vm.envBytes32("CLF_DONID_ARBITRUM"),
                functionsRouter: vm.envAddress("CLF_ROUTER_ARBITRUM")
            });
        uint64 chainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM"));
        uint256 chainIndex = 0; // IInfraStorage.Chain.arb
        address link = vm.envAddress("LINK_ARBITRUM");
        address ccipRouter = vm.envAddress("CL_CCIP_ROUTER_ARBITRUM");
        address dexswap = vm.envAddress("CONCERO_DEX_SWAP_ARBITRUM");
        address pool = address(parentPoolProxy); // should(?) be child pool on arbitrum?
        address proxy = address(arbitrumOrchestratorProxy);
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];

        arbitrumBridgeImplementation = _deployBridge(
            functionsVariables,
            chainSelector,
            chainIndex,
            link,
            ccipRouter,
            dexswap,
            pool,
            proxy,
            messengers
        );
    }

    function _deployAvalancheBridgeImplementation() internal {
        IInfraStorage.FunctionsVariables memory functionsVariables = IInfraStorage
            .FunctionsVariables({
                subscriptionId: uint64(vm.envUint("CLF_SUBID_AVALANCHE")),
                donId: vm.envBytes32("CLF_DONID_AVALANCHE"),
                functionsRouter: vm.envAddress("CLF_ROUTER_AVALANCHE")
            });
        uint64 chainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE"));
        uint256 chainIndex = 4; // IInfraStorage.Chain.avax
        address link = vm.envAddress("LINK_AVALANCHE");
        address ccipRouter = vm.envAddress("CL_CCIP_ROUTER_AVALANCHE");
        address dexswap = address(avalancheDexSwap);
        address pool = address(parentPoolProxy);
        address proxy = address(avalancheOrchestratorProxy); // avalancheOrchestratorProxy
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];

        avalancheBridgeImplementation = _deployBridge(
            functionsVariables,
            chainSelector,
            chainIndex,
            link,
            ccipRouter,
            dexswap,
            pool,
            proxy,
            messengers
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ORCHESTRATOR
    //////////////////////////////////////////////////////////////*/
    function _deployOrchestratorProxy() internal {
        vm.prank(proxyDeployer);
        baseOrchestratorProxy = new TransparentUpgradeableProxy(
            vm.envAddress("CONCERO_PAUSE_BASE"),
            proxyDeployer,
            bytes("")
        );
    }

    function _deployOrchestratorImplementation() internal {
        vm.prank(deployer);
        baseOrchestratorImplementation = new InfraOrchestrator(
            vm.envAddress("CLF_ROUTER_BASE"),
            address(dexSwap),
            address(baseBridgeImplementation),
            address(parentPoolProxy),
            address(baseOrchestratorProxy),
            1, // IInfraStorage.Chain.base
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    /*//////////////////////////////////////////////////////////////
                                DEXSWAP
    //////////////////////////////////////////////////////////////*/
    function _deployDexSwap() internal {
        vm.prank(deployer);
        dexSwap = new DexSwap(
            address(baseOrchestratorProxy),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
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
                               AVALANCHE
    //////////////////////////////////////////////////////////////*/
    function _deployAvalancheInfra() internal {
        _deployOrchestratorProxyAvalanche();
        _deployDexSwapAvalanche();
        _deployAvalancheBridgeImplementation();

        (avalancheChildProxy, avalancheChildImplementation) = _deployChildPoolAvalanche(
            address(avalancheOrchestratorProxy),
            vm.envAddress("LINK_AVALANCHE"),
            vm.envAddress("CL_CCIP_ROUTER_AVALANCHE"),
            vm.envAddress("USDC_AVALANCHE"),
            baseChainSelector, // parentPool chain selector
            address(parentPoolProxy)
        );
        vm.selectFork(forkId);
        setParentPoolVars(avalancheChainSelector, avalancheChildProxy);
        _setDstSelectorAndBridge(avalancheChainSelector, address(avalancheOrchestratorProxy)); // avalancheOrchestratorProxy
        vm.selectFork(avalancheFork);

        _deployOrchestratorImplementationAvalanche();

        _setProxyImplementation(
            address(avalancheOrchestratorProxy),
            address(avalancheOrchestratorImplementation)
        );

        addFunctionsConsumer(
            vm.envAddress("CLF_ROUTER_AVALANCHE"),
            address(avalancheOrchestratorProxy),
            uint64(vm.envUint("CLF_SUBID_AVALANCHE"))
        );
    }

    function _deployOrchestratorProxyAvalanche() internal {
        vm.prank(proxyDeployer);
        avalancheOrchestratorProxy = new TransparentUpgradeableProxy(
            vm.envAddress("CONCERO_PAUSE_AVALANCHE"),
            proxyDeployer,
            bytes("")
        );
    }

    function _deployDexSwapAvalanche() internal {
        vm.prank(deployer);
        avalancheDexSwap = new DexSwap(
            address(avalancheOrchestratorProxy),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function _deployOrchestratorImplementationAvalanche() internal {
        vm.prank(deployer);
        avalancheOrchestratorImplementation = new InfraOrchestrator(
            vm.envAddress("CLF_ROUTER_AVALANCHE"),
            address(avalancheDexSwap),
            address(avalancheBridgeImplementation),
            address(avalancheChildProxy),
            address(avalancheOrchestratorProxy),
            4, // IInfraStorage.Chain.avax
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function _deployChildPoolProxyAvalanche() internal returns (address) {
        vm.prank(proxyDeployer);
        TransparentUpgradeableProxy avalancheChildPoolProxy = new TransparentUpgradeableProxy(
            vm.envAddress("CONCERO_PAUSE_AVALANCHE"),
            proxyDeployer,
            bytes("")
        );
        return address(avalancheChildPoolProxy);
    }

    function _deployChildPoolAvalanche(
        address _infraProxy,
        address _link,
        address _ccipRouter,
        address _usdc,
        uint64 _parentPoolChainSelector,
        address _parentProxy
    ) internal returns (address, address) {
        address avalancheChildProxy = _deployChildPoolProxy();
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];

        address childImplementation = _deployChildPoolImplementation(
            _infraProxy,
            avalancheChildProxy,
            _link,
            _ccipRouter,
            _usdc,
            deployer,
            messengers
        );

        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(avalancheChildProxy).upgradeToAndCall(
            childImplementation,
            bytes("")
        );

        /// set the parentPool in childProxy.setPools();
        vm.prank(deployer);
        (bool success, ) = address(avalancheChildProxy).call(
            abi.encodeWithSignature(
                "setPools(uint64,address)",
                _parentPoolChainSelector,
                _parentProxy
            )
        );
        require(success, "childProxy.setPools with parentPool failed");

        return (avalancheChildProxy, childImplementation);
    }
}
