// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {TransparentUpgradeableProxy} from "contracts/transparentProxy/TransparentUpgradeableProxy.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {LPToken} from "contracts/LPToken.sol";
import {CCIPLocalSimulator} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPLocalSimulatorFork} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {Register} from "../../../lib/chainlink-local/src/ccip/Register.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {Orchestrator} from "contracts/Orchestrator.sol";
import {IStorage} from "contracts/Interfaces/IStorage.sol";

contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant CCIP_FEES = 100 * 1e18;

    ConceroParentPool public parentPoolImplementation;
    ParentPoolProxy public parentPoolProxy;
    LPToken public lpToken;
    FunctionsSubscriptions public functionsSubscriptions;
    CCIPLocalSimulator public ccipLocalSimulator;
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address messenger = vm.envAddress("POOL_MESSENGER_0_ADDRESS");

    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");
    uint256 internal forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
    address internal usdc = vm.envAddress("USDC_BASE");
    address internal link = vm.envAddress("LINK_BASE");
    uint64 internal baseChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE"));
    uint64 internal optimismChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_OPTIMISM"));
    uint64 internal arbitrumChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM"));
    uint64 internal avalancheChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE"));
    uint64 internal polygonChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_POLYGON"));

    address arbitrumChildProxy;
    address arbitrumChildImplementation;
    address avalancheChildProxy = address(3);

    ConceroBridge internal baseBridgeImplementation;
    ConceroBridge internal arbitrumBridgeImplementation;
    ConceroBridge internal avalancheBridgeImplementation;

    TransparentUpgradeableProxy internal baseOrchestratorProxy;
    Orchestrator internal baseOrchestratorImplementation;
    address internal arbitrumOrchestratorProxy = address(1);
    address internal avalancheOrchestratorProxy = address(2);

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        vm.selectFork(forkId);

        _deployOrchestratorProxy();

        deployBridgesInfra();

        deployPoolsInfra();

        _deployOrchestratorImplementation();
        _setProxyImplementation(
            address(baseOrchestratorProxy),
            address(baseOrchestratorImplementation)
        );

        /// @dev set destination chain selector and contracts on Base
        _setDstSelectorAndPool(arbitrumChainSelector, arbitrumChildProxy);
        _setDstSelectorAndBridge(arbitrumChainSelector, arbitrumOrchestratorProxy);
    }

    function deployPoolsInfra() public {
        deployParentPoolProxy();
        deployLpToken();
        _deployParentPool();
        _setProxyImplementation(address(parentPoolProxy), address(parentPoolImplementation));

        /// @dev set initial child pool
        (arbitrumChildProxy, arbitrumChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_PROXY_ARBITRUM"),
            vm.envAddress("LINK_ARBITRUM"),
            vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_ARBITRUM"),
            optimismChainSelector,
            address(parentPoolProxy)
        );
        setParentPoolVars(arbitrumChainSelector, arbitrumChildProxy);

        _deployCcipLocalSimulation();
        addFunctionsConsumer(address(parentPoolProxy));
        _fundLinkParentProxy(CCIP_FEES);
    }

    function deployBridgesInfra() public {
        _deployBaseBridgeImplementation();

        _deployArbitrumBridgeImplementation();

        _deployAvalancheBridgeImplementation();

        addFunctionsConsumer(address(baseOrchestratorProxy));
    }

    /*//////////////////////////////////////////////////////////////
                              DEPLOYMENTS
    //////////////////////////////////////////////////////////////*/
    function deployParentPoolProxy() public {
        vm.prank(proxyDeployer);
        parentPoolProxy = new ParentPoolProxy(
            vm.envAddress("CONCERO_PAUSE_BASE"),
            proxyDeployer,
            bytes("")
        );
    }

    function _deployParentPool() private {
        // Deploy the default ConceroParentPool if no custom address is provided
        vm.prank(deployer);
        parentPoolImplementation = new ConceroParentPool(
            address(parentPoolProxy),
            vm.envAddress("LINK_BASE"),
            vm.envBytes32("CLF_DONID_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            address(baseOrchestratorProxy), // vm.envAddress("CONCERO_ORCHESTRATOR_BASE")
            vm.envAddress("CONCERO_AUTOMATION_BASE"), // not in cla-parent merge
            address(deployer),
            // 0, // slotId
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
    function addFunctionsConsumer(address _consumer) public {
        vm.prank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions = FunctionsSubscriptions(
            address(0xf9B8fc078197181C841c296C876945aaa425B278)
        );
        functionsSubscriptions.addConsumer(uint64(vm.envUint("CLF_SUBID_BASE")), _consumer);
    }

    function _fundLinkParentProxy(uint256 amount) internal {
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), amount);
    }

    function _fundFunctionsSubscription() internal {
        address linkAddress = vm.envAddress("LINK_BASE");
        LinkTokenInterface link = LinkTokenInterface(vm.envAddress("LINK_BASE"));
        address router = vm.envAddress("CLF_ROUTER_BASE");
        bytes memory data = abi.encode(uint64(vm.envUint("CLF_SUBID_BASE")));

        uint256 funds = 100 * 1e18; // 100 LINK

        address subFunder = makeAddr("subFunder");
        deal(linkAddress, subFunder, funds);

        vm.prank(subFunder);
        link.transferAndCall(router, funds, data);
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
        ConceroChildPool childPool = new ConceroChildPool(
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
        ChildPoolProxy childPoolProxy = new ChildPoolProxy(
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
        IStorage.FunctionsVariables memory _variables,
        uint64 _chainSelector,
        uint256 _chainIndex,
        address _link,
        address _ccipRouter,
        address _dexSwap,
        address _pool,
        address _proxy,
        address[3] memory _messengers,
        address _functionsCoordinator,
        address _priceRegistry,
        uint64 _subscriptionId
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
                _messengers,
                _functionsCoordinator,
                _priceRegistry,
                _subscriptionId
            );
    }

    function _deployBaseBridgeImplementation() internal {
        IStorage.FunctionsVariables memory functionsVariables = IStorage.FunctionsVariables({
            subscriptionId: uint64(vm.envUint("CLF_SUBID_BASE")),
            donId: vm.envBytes32("CLF_DONID_BASE"),
            functionsRouter: vm.envAddress("CLF_ROUTER_BASE")
        });
        uint64 chainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE"));
        uint256 chainIndex = 1; // IStorage.Chain.base
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
        address functionsCoordinator = 0xd93d77789129c584a02B9Fd3BfBA560B2511Ff8A;
        address priceRegistry = 0x6337a58D4BD7Ba691B66341779e8f87d4679923a;

        baseBridgeImplementation = _deployBridge(
            functionsVariables,
            chainSelector,
            chainIndex,
            link,
            ccipRouter,
            dexswap,
            pool,
            proxy,
            messengers,
            functionsCoordinator,
            priceRegistry,
            uint64(vm.envUint("CLF_SUBID_BASE"))
        );
    }

    function _deployArbitrumBridgeImplementation() internal {
        IStorage.FunctionsVariables memory functionsVariables = IStorage.FunctionsVariables({
            subscriptionId: uint64(vm.envUint("CLF_SUBID_ARBITRUM")),
            donId: vm.envBytes32("CLF_DONID_ARBITRUM"),
            functionsRouter: vm.envAddress("CLF_ROUTER_ARBITRUM")
        });
        uint64 chainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM"));
        uint256 chainIndex = 0; // IStorage.Chain.arb
        address link = vm.envAddress("LINK_ARBITRUM");
        address ccipRouter = vm.envAddress("CL_CCIP_ROUTER_ARBITRUM");
        address dexswap = vm.envAddress("CONCERO_DEX_SWAP_ARBITRUM");
        address pool = address(parentPoolProxy);
        address proxy = address(0); // arbitrumOrchestratorProxy
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];
        address functionsCoordinator;
        address priceRegistry;

        arbitrumBridgeImplementation = _deployBridge(
            functionsVariables,
            chainSelector,
            chainIndex,
            link,
            ccipRouter,
            dexswap,
            pool,
            proxy,
            messengers,
            functionsCoordinator,
            priceRegistry,
            uint64(vm.envUint("CLF_SUBID_ARBITRUM"))
        );
    }

    function _deployAvalancheBridgeImplementation() internal {
        IStorage.FunctionsVariables memory functionsVariables = IStorage.FunctionsVariables({
            subscriptionId: uint64(vm.envUint("CLF_SUBID_AVALANCHE")),
            donId: vm.envBytes32("CLF_DONID_AVALANCHE"),
            functionsRouter: vm.envAddress("CLF_ROUTER_AVALANCHE")
        });
        uint64 chainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE"));
        uint256 chainIndex = 4; // IStorage.Chain.avax
        address link = vm.envAddress("LINK_AVALANCHE");
        address ccipRouter = vm.envAddress("CL_CCIP_ROUTER_AVALANCHE");
        address dexswap = vm.envAddress("CONCERO_DEX_SWAP_AVALANCHE");
        address pool = address(parentPoolProxy);
        address proxy = address(0); // arbitrumOrchestratorProxy
        address[3] memory messengers = [
            vm.envAddress("POOL_MESSENGER_0_ADDRESS"),
            address(0),
            address(0)
        ];
        address functionsCoordinator;
        address priceRegistry;

        avalancheBridgeImplementation = _deployBridge(
            functionsVariables,
            chainSelector,
            chainIndex,
            link,
            ccipRouter,
            dexswap,
            pool,
            proxy,
            messengers,
            functionsCoordinator,
            priceRegistry,
            uint64(vm.envUint("CLF_SUBID_AVALANCHE"))
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
        baseOrchestratorImplementation = new Orchestrator(
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CONCERO_DEX_SWAP_BASE"),
            address(baseBridgeImplementation),
            address(parentPoolProxy),
            address(baseOrchestratorProxy),
            1, // IStorage.Chain.base
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }
}
