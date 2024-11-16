// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import {ParentPool} from "contracts/ParentPool.sol";
import {ParentPoolCLFCLA} from "contracts/ParentPoolCLFCLA.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/TransparentUpgradeableProxy.sol";
import {ChildPool} from "contracts/ChildPool.sol";
import {LPToken} from "contracts/LPToken.sol";
//import {CCIPLocalSimulator} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
//import {CCIPLocalSimulatorFork} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
//import {Register} from "../../../lib/chainlink-local/src/ccip/Register.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {InfraOrchestrator} from "contracts/InfraOrchestrator.sol";
import {IInfraStorage} from "contracts/Interfaces/IInfraStorage.sol";
//import {IOwner} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IOwner.sol";
import {DexSwap} from "contracts/DexSwap.sol";

contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant LINK_INIT_BALANCE = 100 * 1e18;
    uint256 internal constant USDC_DECIMALS = 1e6;
    uint256 internal constant PARENT_POOL_CAP = 100_000_000 * USDC_DECIMALS;

    ParentPoolCLFCLA public parentPoolCLFCLA;
    ParentPool public parentPoolImplementation;
    TransparentUpgradeableProxy public parentPoolProxy;
    LPToken public lpToken;
    DexSwap public dexSwap;
    FunctionsSubscriptions public functionsSubscriptions;
    //    CCIPLocalSimulator public ccipLocalSimulator;
    //    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    address internal messenger = vm.envAddress("POOL_MESSENGER_0_ADDRESS");

    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");
    uint256 internal baseAnvilForkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));

    uint64 internal baseChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE"));
    uint64 internal optimismChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_OPTIMISM"));
    uint64 internal arbitrumChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM"));
    uint64 internal avalancheChainSelector = uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_AVALANCHE"));

    address internal arbitrumChildProxy = makeAddr("arbChildPool");
    address internal arbitrumChildImplementation;
    address internal avalancheChildProxy;
    address internal avalancheChildImplementation;

    ConceroBridge internal baseBridgeImplementation;
    ConceroBridge internal arbitrumBridgeImplementation;
    ConceroBridge internal avalancheBridgeImplementation;

    TransparentUpgradeableProxy internal baseOrchestratorProxy;
    InfraOrchestrator internal baseOrchestratorImplementation;
    address internal arbitrumOrchestratorProxy = address(1);
    address internal avalancheOrchestratorProxy = address(2);

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        vm.selectFork(baseAnvilForkId);

        _deployOrchestratorProxy();
        deployInfra();
        deployPoolsInfra();
        _deployOrchestratorImplementation();

        _setProxyImplementation(
            address(baseOrchestratorProxy),
            address(baseOrchestratorImplementation)
        );

        _setDstInfraContractsForInfra(
            address(baseOrchestratorProxy),
            arbitrumChainSelector,
            arbitrumOrchestratorProxy
        );
    }

    function deployPoolsInfra() public {
        deployParentPoolProxy();
        deployLpToken();
        _deployParentPool();
        _setProxyImplementation(address(parentPoolProxy), address(parentPoolImplementation));

        //        _deployCcipLocalSimulation();
        addFunctionsConsumer(address(parentPoolProxy));
        _fundLinkParentProxy(LINK_INIT_BALANCE);
    }

    function deployInfra() public {
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
        parentPoolProxy = new TransparentUpgradeableProxy(
            vm.envAddress("CONCERO_PAUSE_BASE"),
            proxyDeployer,
            bytes("")
        );
        vm.stopPrank();
    }

    function _deployChildPools() public {
        (arbitrumChildProxy, arbitrumChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_INFRA_PROXY_ARBITRUM"),
            vm.envAddress("LINK_ARBITRUM"),
            vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_ARBITRUM"),
            optimismChainSelector,
            address(parentPoolProxy)
        );
        _setChildPoolForParentPool(arbitrumChainSelector, arbitrumChildProxy);

        (avalancheChildProxy, avalancheChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_INFRA_PROXY_AVALANCHE"),
            vm.envAddress("LINK_AVALANCHE"),
            vm.envAddress("CL_CCIP_ROUTER_AVALANCHE"),
            vm.envAddress("USDC_AVALANCHE"),
            avalancheChainSelector,
            address(parentPoolProxy)
        );

        _setChildPoolForParentPool(avalancheChainSelector, avalancheChildProxy);
    }

    function _deployParentPool() private {
        vm.prank(proxyDeployer);
        parentPoolCLFCLA = new ParentPoolCLFCLA(
            address(parentPoolProxy),
            address(lpToken),
            vm.envAddress("USDC_BASE"),
            vm.envAddress("CLF_ROUTER_BASE"),
            uint64(vm.envUint("CLF_SUBID_BASE")),
            vm.envBytes32("CLF_DONID_BASE"),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
        vm.stopPrank();

        vm.prank(deployer);
        parentPoolImplementation = new ParentPool(
            address(parentPoolProxy),
            address(parentPoolCLFCLA),
            address(0),
            vm.envAddress("LINK_BASE"),
            vm.envAddress("CL_CCIP_ROUTER_BASE"),
            vm.envAddress("USDC_BASE"),
            address(lpToken),
            address(baseOrchestratorProxy),
            vm.envAddress("CLF_ROUTER_BASE"),
            address(deployer),
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
        vm.stopPrank();
    }

    function deployLpToken() public {
        vm.prank(deployer);
        lpToken = new LPToken(deployer, address(parentPoolProxy));
        vm.stopPrank();
    }

    //    function _deployCCIPLocalSimulatorFork() internal {
    //        uint256 BASE_CHAIN_ID = 8453;
    //
    //        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
    //        vm.makePersistent(address(ccipLocalSimulatorFork));
    //
    //        Register.NetworkDetails memory baseDetails = Register.NetworkDetails({
    //            chainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_BASE")),
    //            routerAddress: vm.envAddress("CL_CCIP_ROUTER_BASE"),
    //            linkAddress: vm.envAddress("LINK_BASE"),
    //            wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
    //            ccipBnMAddress: address(0),
    //            ccipLnMAddress: address(0),
    //            rmnProxyAddress: address(0),
    //            registryModuleOwnerCustomAddress: address(0),
    //            tokenAdminRegistryAddress: address(0)
    //        });
    //
    //        ccipLocalSimulatorFork.setNetworkDetails(BASE_CHAIN_ID, baseDetails);
    //    }
    //
    //    function _deployCcipLocalSimulation() private {
    //        ccipLocalSimulator = new CCIPLocalSimulator();
    //        ccipLocalSimulator.configuration();
    //        //        vm.prank(IOwner(vm.envAddress("USDC_BASE")).owner());
    //        ccipLocalSimulator.supportNewTokenViaOwner(vm.envAddress("USDC_BASE"));
    //    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/
    function _setProxyImplementation(address _proxy, address _implementation) internal {
        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(address(_proxy)).upgradeToAndCall(_implementation, bytes(""));
    }

    function _setParentPoolVars() public {
        _deployChildPools();

        vm.prank(deployer);
        IParentPool(address(parentPoolProxy)).setConceroContractSender(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            address(arbitrumChildProxy),
            true
        );

        vm.prank(deployer);
        IParentPool(address(parentPoolProxy)).setPoolCap(PARENT_POOL_CAP);
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function addFunctionsConsumer(address _consumer) public {
        vm.prank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions = FunctionsSubscriptions(address(vm.envAddress("CLF_ROUTER_BASE")));
        functionsSubscriptions.addConsumer(uint64(vm.envUint("CLF_SUBID_BASE")), _consumer);
        vm.stopPrank();
    }

    function _fundLinkParentProxy(uint256 amount) internal {
        deal(vm.envAddress("LINK_BASE"), address(parentPoolProxy), amount);
    }

    function _fundFunctionsSubscription() internal {
        address linkAddress = vm.envAddress("LINK_BASE");
        address _link = (vm.envAddress("LINK_BASE"));
        address router = vm.envAddress("CLF_ROUTER_BASE");
        bytes memory data = abi.encode(uint64(vm.envUint("CLF_SUBID_BASE")));

        uint256 funds = 100 * 1e18; // 100 LINK

        address subFunder = makeAddr("subFunder");
        deal(linkAddress, subFunder, funds);

        vm.prank(subFunder);
        LinkTokenInterface(_link).transferAndCall(router, funds, data);
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
            _owner,
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
        //        _setChildPoolForInfra(address(arbitrumChildProxy), _parentPoolChainSelector, _parentProxy);

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
        ConceroBridge conceroBridge;
        vm.prank(deployer);
        conceroBridge = new ConceroBridge(
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
        return conceroBridge;
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
        address pool = address(parentPoolProxy);
        address proxy = address(0); // arbitrumOrchestratorProxy
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
        address dexswap = vm.envAddress("CONCERO_DEX_SWAP_AVALANCHE");
        address pool = address(parentPoolProxy);
        address proxy = address(0); // arbitrumOrchestratorProxy
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
        vm.stopPrank();
    }

    function _deployOrchestratorImplementation() internal {
        vm.prank(deployer);
        baseOrchestratorImplementation = new InfraOrchestrator(
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CONCERO_DEX_SWAP_BASE"),
            address(baseBridgeImplementation),
            address(parentPoolProxy),
            address(baseOrchestratorProxy),
            1, // IInfraStorage.Chain.base
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    /*//////////////////////////////////////////////////////////////
								 UTILS
	   //////////////////////////////////////////////////////////////*/

    function _mintLpToken(address to, uint256 amount) internal {
        vm.prank(address(parentPoolProxy));
        lpToken.mint(to, amount);
    }

    function _mintUSDC(address to, uint256 amount) internal {
        deal(address(vm.envAddress("USDC_BASE")), to, amount);
    }

    function _mintLink(address to, uint256 amount) internal {
        deal(vm.envAddress("LINK_BASE"), to, amount);
    }

    function _approve(address from, address token, address spender, uint256 amount) internal {
        vm.prank(from);
        IERC20(token).approve(spender, amount);
    }

    /*//////////////////////////////////////////////////////////////
								PARENT POOL UTILS
	   //////////////////////////////////////////////////////////////*/

    function _setChildPoolForParentPool(uint64 chainSelector, address childPool) internal {
        vm.prank(deployer);
        (bool success, bytes memory data) = address(parentPoolProxy).call(
            abi.encodeWithSignature(
                "setPools(uint64,address,bool)",
                chainSelector,
                childPool,
                false
            )
        );
        require(success, string(data));
    }

    /*//////////////////////////////////////////////////////////////
							 CONCERO INFRA UTILS
	//////////////////////////////////////////////////////////////*/

    function _setDstPoolForInfra(address infra, uint64 chainSelector, address childPool) internal {
        vm.prank(deployer);
        (bool success, bytes memory data) = infra.call(
            abi.encodeWithSignature(
                "setDstConceroPool(uint64,address)",
                chainSelector,
                childPool,
                false
            )
        );
        require(success, string(data));
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
    function _getBaseInfraImplementationConstructorArgs()
        internal
        returns (address, address, address, address, address, uint8, address[3] memory)
    {
        return (
            vm.envAddress("CLF_ROUTER_BASE"),
            vm.envAddress("CONCERO_DEX_SWAP_BASE"),
            address(baseBridgeImplementation),
            address(parentPoolProxy),
            address(baseOrchestratorProxy),
            1, // IInfraStorage.Chain.base
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function _setDstInfraContractsForInfra(
        address infra,
        uint64 _chainSelector,
        address _bridgeProxy
    ) internal {
        vm.prank(deployer);

        (bool success, ) = infra.call(
            abi.encodeWithSignature(
                "setConceroContract(uint64,address)",
                _chainSelector,
                _bridgeProxy
            )
        );
        require(success, "setConceroContract call failed");
    }
}
