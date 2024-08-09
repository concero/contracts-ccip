// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {ParentPoolProxy, ITransparentUpgradeableProxy} from "contracts/Proxy/ParentPoolProxy.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {LPToken} from "contracts/LPToken.sol";
import {CCIPLocalSimulator} from "../../../lib/chainlink-local/src/ccip/CCIPLocalSimulator.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {FunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsSubscriptions.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

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

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    address internal deployer = vm.envAddress("FORGE_DEPLOYER_ADDRESS");
    address internal proxyDeployer = vm.envAddress("FORGE_PROXY_DEPLOYER_ADDRESS");
    uint256 internal forkId = vm.createFork(vm.envString("LOCAL_BASE_FORK_RPC_URL"));
    address internal usdc = vm.envAddress("USDC_BASE");
    address internal link = vm.envAddress("LINK_BASE");

    address arbitrumChildProxy;
    address arbitrumChildImplementation;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        vm.selectFork(forkId);
        deployPoolsInfra();
    }

    function deployPoolsInfra() public {
        deployParentPoolProxy();
        _deployParentPool();
        setProxyImplementation(address(parentPoolImplementation));

        /// @dev set initial child pool
        (arbitrumChildProxy, arbitrumChildImplementation) = _deployChildPool(
            vm.envAddress("CONCERO_PROXY_ARBITRUM"),
            vm.envAddress("LINK_ARBITRUM"),
            vm.envAddress("CL_CCIP_ROUTER_ARBITRUM"),
            vm.envAddress("USDC_ARBITRUM")
        );
        setParentPoolVars(uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")), arbitrumChildProxy);

        _deployCcipLocalSimulation();
        deployLpToken();
        addFunctionsConsumer();
        _fundLinkParentProxy(CCIP_FEES);
    }

    /*//////////////////////////////////////////////////////////////
                              DEPLOYMENTS
    //////////////////////////////////////////////////////////////*/
    function deployParentPoolProxy() public {
        vm.prank(proxyDeployer);
        parentPoolProxy = new ParentPoolProxy(vm.envAddress("CONCERO_PAUSE_BASE"), proxyDeployer, bytes(""));
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
            vm.envAddress("CONCERO_ORCHESTRATOR_BASE"),
            address(deployer),
            0, // slotId
            [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)]
        );
    }

    function deployLpToken() public {
        vm.prank(deployer);
        lpToken = new LPToken(deployer, address(parentPoolProxy));
    }

    function _deployCcipLocalSimulation() private {
        ccipLocalSimulator = new CCIPLocalSimulator();
        ccipLocalSimulator.configuration();
        ccipLocalSimulator.supportNewToken(vm.envAddress("USDC_BASE"));
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/
    function setProxyImplementation(address _parentPoolImplementation) public {
        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(address(parentPoolProxy)).upgradeToAndCall(_parentPoolImplementation, bytes(""));
    }

    /// @notice might need to update this to pass _parentPoolImplementation like above
    function setParentPoolVars(uint64 _chainSelector, address _childProxy) public {
        vm.prank(deployer);
        IParentPool(address(parentPoolProxy)).setPools(_chainSelector, _childProxy, false);

        vm.prank(deployer);
        // should probably update this from user1
        IParentPool(address(parentPoolProxy)).setConceroContractSender(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")), address(user1), 1
        );
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function addFunctionsConsumer() public {
        vm.prank(vm.envAddress("DEPLOYER_ADDRESS"));
        functionsSubscriptions = FunctionsSubscriptions(address(0xf9B8fc078197181C841c296C876945aaa425B278));
        functionsSubscriptions.addConsumer(uint64(vm.envUint("CLF_SUBID_BASE")), address(parentPoolProxy));
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
        ConceroChildPool childPool =
            new ConceroChildPool(_infraProxy, _proxy, _link, _ccipRouter, _usdc, deployer, _messengers);

        return address(childPool);
    }

    function _deployChildPoolProxy() internal returns (address) {
        vm.prank(proxyDeployer);
        ChildPoolProxy childPoolProxy =
            new ChildPoolProxy(vm.envAddress("CONCERO_PAUSE_BASE"), proxyDeployer, bytes(""));
        return address(childPoolProxy);
    }

    function _deployChildPool(address _infraProxy, address _link, address _ccipRouter, address _usdc)
        internal
        returns (address, address)
    {
        address childProxy = _deployChildPoolProxy();
        address[3] memory messengers = [vm.envAddress("POOL_MESSENGER_0_ADDRESS"), address(0), address(0)];

        address childImplementation =
            _deployChildPoolImplementation(_infraProxy, childProxy, _link, _ccipRouter, _usdc, deployer, messengers);

        vm.prank(proxyDeployer);
        ITransparentUpgradeableProxy(childProxy).upgradeToAndCall(childImplementation, bytes(""));

        return (childProxy, childImplementation);
    }
}
