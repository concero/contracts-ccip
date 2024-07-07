// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//Foundry
import {Test, console2} from "forge-std/Test.sol";

//Master & Infra Contracts
import {DexSwap} from "contracts/DexSwap.sol";
import {ParentPool} from "contracts/ParentPool.sol";
import {ConceroBridge} from "contracts/ConceroBridge.sol";
import {Orchestrator} from "contracts/Orchestrator.sol";
import {LPToken} from "contracts/LPToken.sol";
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";
import {InfraProxy} from "contracts/Proxy/InfraProxy.sol";
import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";

///=== Child Contracts
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";

//Interfaces
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IStorage} from "contracts/Interfaces/IStorage.sol";

//Protocol Storage
import {Storage} from "contracts/Libraries/Storage.sol";

//MAster & Infra Scripts
import {DexSwapDeploy} from "../../../script/DexSwapDeploy.s.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ConceroDeploy} from "../../../script/ConceroDeploy.s.sol";
import {OrchestratorDeploy} from "../../../script/OrchestratorDeploy.s.sol";
import {InfraProxyDeploy} from "../../../script/InfraProxyDeploy.s.sol";
import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";
import {AutomationDeploy} from "../../../script/AutomationDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";

//===== Child Scripts
import {ChildPoolDeploy} from "../../../script/ChildPoolDeploy.s.sol";
import {ChildPoolProxyDeploy} from "../../../script/ChildPoolProxyDeploy.s.sol";

//Mocks
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {USDC} from "../../Mocks/USDC.sol";

//OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

//DEXes routers
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {ISwapRouter02, IV3SwapRouter} from "contracts/Interfaces/ISwapRouter02.sol";

//Chainlink
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";
import {LinkToken} from "@chainlink/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract ProtocolTest is Test {
    //==== Instantiate Base Contracts
    DexSwap public dex;
    ParentPool public pool;
    ConceroBridge public concero;
    Orchestrator public orch;
    Orchestrator public orchEmpty;
    InfraProxy public proxy;
    LPToken public lp;
    ConceroAutomation public automation;
    ParentPoolProxy masterProxy;
    ITransparentUpgradeableProxy proxyInterfaceInfra;
    ITransparentUpgradeableProxy proxyInterfaceMaster;

    //==== Instantiate Deploy Script Base
    DexSwapDeploy dexDeployBase;
    ParentPoolDeploy poolDeployBase;
    ConceroDeploy conceroDeployBase;
    OrchestratorDeploy orchDeployBase;
    InfraProxyDeploy proxyDeployBase;
    LPTokenDeploy lpDeployBase;
    AutomationDeploy autoDeployBase;
    ParentPoolProxyDeploy masterProxyDeploy;

    //==== Instantiate Arbitrum Contracts
    DexSwap public dexDst;
    ConceroChildPool public child;
    ConceroBridge public conceroDst;
    Orchestrator public orchDst;
    Orchestrator public orchEmptyDst;
    InfraProxy public proxyDst;
    ChildPoolProxy public childProxy;
    ITransparentUpgradeableProxy proxyInterfaceInfraArb;
    ITransparentUpgradeableProxy proxyInterfaceChild;

    //==== Instantiate Deploy Script Arbitrum
    InfraProxyDeploy proxyDeployArbitrum;
    ChildPoolProxyDeploy childProxyDeploy;

    DexSwapDeploy dexDeployArbitrum;
    ChildPoolDeploy childDeployArbitrum;
    ConceroDeploy conceroDeployArbitrum;
    OrchestratorDeploy orchDeployArbitrum;

    //==== Wrapped contract
    Orchestrator op;
    Orchestrator opDst;
    ParentPool wMaster;
    ConceroChildPool wChild;


    //==== Create the instance to forked tokens
    IWETH wEth;
    IWETH arbWEth;
    USDC public mUSDC;
    USDC public aUSDC;
    ERC20Mock AERO;

    //==== Instantiate Base DEXes Routers
    IUniswapV2Router02 uniswapV2;
    IUniswapV2Router02 sushiV2;
    ISwapRouter02 uniswapV3;
    ISwapRouter sushiV3;
    IRouter aerodromeRouter;

    //==== Instantiate Arbitrum DEXes Routers
    IUniswapV2Router02 uniswapV2Arb;
    IUniswapV2Router02 sushiV2Arb;
    ISwapRouter02 uniswapV3Arb;
    ISwapRouter sushiV3Arb;

    //==== Instantiate Chainlink Forked CCIP
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint64 baseChainSelector = 15971525489660198786;
    uint64 arbChainSelector = 4949039107694359620;

    //Base Mainnet variables
    address linkBase = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address ccipRouterBase = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    FunctionsRouter functionsRouterBase = FunctionsRouter(0xf9B8fc078197181C841c296C876945aaa425B278);
    bytes32 donIdBase = 0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000;
    address linkOwnerBase = 0x7B0328745A01634c32eFAf041d91432a075B308D;

    //Arb Mainnet variables
    address linkArb = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address ccipRouterArb = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    FunctionsRouter functionsRouterArb = FunctionsRouter(0x97083E831F8F0638855e2A515c90EdCF158DF238);
    bytes32 donIdArb = 0x66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000;

    address ProxyOwner = makeAddr("ProxyOwner");
    address Tester = makeAddr("Tester");
    address User = makeAddr("User");
    address Messenger = makeAddr("Messenger");
    address LP = makeAddr("LiquidityProvider");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address subOwner = 0xDddDDb8a8E41C194ac6542a0Ad7bA663A72741E0;

    uint256 baseMainFork;
    uint256 arbitrumMainFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    string ARB_RPC_URL = vm.envString("ARB_RPC_URL");
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant LINK_BALANCE = 1 ether;
    uint256 constant USDC_INITIAL_BALANCE = 10 * 10**6;
    uint256 constant LP_INITIAL_BALANCE = 2 ether;
    ERC721 SAFE_LOCK;

    function setUp() public {
        baseMainFork = vm.createSelectFork(BASE_RPC_URL);
        arbitrumMainFork = vm.createFork(ARB_RPC_URL);
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        //Base Network details
        Register.NetworkDetails memory base = Register.NetworkDetails({
            chainSelector: baseChainSelector,
            routerAddress: ccipRouterBase,
            linkAddress: linkBase,
            wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
            ccipBnMAddress: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            ccipLnMAddress: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        });

        ccipLocalSimulatorFork.setNetworkDetails(
            8453,
            base
        );

        //Arbitrum Network details
        Register.NetworkDetails memory arbitrum = Register.NetworkDetails({
            chainSelector: arbChainSelector,
            routerAddress: ccipRouterArb,
            linkAddress: linkArb,
            wrappedNativeAddress: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            ccipBnMAddress: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            ccipLnMAddress: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
        });

        ccipLocalSimulatorFork.setNetworkDetails(
            42161,
            arbitrum
        );

        vm.selectFork(baseMainFork);

        //Base Routers
        uniswapV2 = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        sushiV2 = IUniswapV2Router02(0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891);
        uniswapV3 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        sushiV3 = ISwapRouter(0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f);
        aerodromeRouter = IRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);

        wEth = IWETH(0x4200000000000000000000000000000000000006);
        mUSDC = USDC(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        AERO = ERC20Mock(0x940181a94A35A4569E4529A3CDfB74e38FD98631);
        SAFE_LOCK = ERC721(0xde11Bc6a6c47EeaB0476C85672EA7f932f1a78Ed);

        dexDeployBase = new DexSwapDeploy();
        poolDeployBase = new ParentPoolDeploy();
        conceroDeployBase = new ConceroDeploy();
        orchDeployBase = new OrchestratorDeploy();
        proxyDeployBase = new InfraProxyDeploy();
        lpDeployBase = new LPTokenDeploy();
        autoDeployBase = new AutomationDeploy();
        masterProxyDeploy = new ParentPoolProxyDeploy();

        {
        //DEPLOY AN DUMMY ORCH
        orchEmpty = orchDeployBase.run(
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            1
        );

        //====== Deploy the proxy with the dummy Orch to get the address
        proxy = proxyDeployBase.run(address(orchEmpty), ProxyOwner, Tester, "");
        masterProxy = masterProxyDeploy.run(address(orchEmpty), ProxyOwner, Tester, "");
        proxyInterfaceInfra = ITransparentUpgradeableProxy(address(proxy));
        proxyInterfaceMaster = ITransparentUpgradeableProxy(address(masterProxy));

        //===== Deploy the protocol with the proxy address
        //LP Token
        lp = lpDeployBase.run(Tester, address(0));

        // Automation Contract
        automation = autoDeployBase.run(
            donIdBase, //_donId
            14, //_subscriptionId
            2, //_slotId
            address(functionsRouterBase), //_router,
            address(masterProxy),
            Tester
        );

        // DexSwap Contract
        dex = dexDeployBase.run(address(proxy), address(wEth));

        concero = conceroDeployBase.run(
            IStorage.FunctionsVariables ({
                subscriptionId: 15, //uint64 _subscriptionId,
                donId: donIdBase,
                functionsRouter: address(functionsRouterBase)
            }),
            baseChainSelector,
            1, //uint _chainIndex,
            linkBase,
            ccipRouterBase,
            address(dex),
            address(masterProxy),
            address(proxy)
        );
        //====== Deploy a new Orch that will e set as implementation to the proxy.
        orch = orchDeployBase.run(
            address(functionsRouterBase),
            address(dex),
            address(concero),
            address(masterProxy),
            address(proxy),
            1
        );

        // Pool Contract
        pool = poolDeployBase.run(
            address(masterProxy),
            linkBase,
            donIdBase,
            14,
            address(functionsRouterBase),
            ccipRouterBase,
            address(mUSDC),
            address(lp),
            address(automation),
            address(orch),
            Tester
        );

        //===== Base Proxies
        //====== Update the proxy for the correct address
        vm.prank(ProxyOwner);
        proxyInterfaceInfra.upgradeToAndCall(address(orch), "");
        vm.prank(ProxyOwner);
        proxyInterfaceMaster.upgradeToAndCall(address(pool), "");

        wMaster = ParentPool(payable(address(masterProxy)));

        //=== Base Contracts
        vm.makePersistent(address(proxy));
        vm.makePersistent(address(dex));
        vm.makePersistent(address(pool));
        vm.makePersistent(address(concero));
        vm.makePersistent(address(orch));
        vm.makePersistent(address(ccipLocalSimulatorFork));
        vm.makePersistent(address(wMaster));

        //====== Update the MINTER on the LP Token
        vm.prank(Tester);
        lp.grantRole(keccak256("MINTER_ROLE"), address(wMaster));

        //====== Wrap the proxy as the implementation
        op = Orchestrator(address(proxy));

        //====== Set the DEXes routers
        vm.startPrank(defaultSender);
        op.setDexRouterAddress(address(uniswapV2), 1);
        op.setDexRouterAddress(address(sushiV2), 1);
        op.setDexRouterAddress(address(uniswapV3), 1);
        op.setDexRouterAddress(address(sushiV3), 1);
        op.setDexRouterAddress(address(aerodromeRouter), 1);
        vm.stopPrank();
        }

        vm.prank(linkOwnerBase);
        LinkToken(linkBase).grantMintRole(Tester);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(op), 10*10**18);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(wMaster), 10*10**18);

        /////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
        //================ SWITCH CHAINS ====================\\
        ///////////////////////////////////////////////////////
        vm.selectFork(arbitrumMainFork);

        //===== Arbitrum Routers
        uniswapV2Arb = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        sushiV2Arb = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        uniswapV3Arb = ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        sushiV3Arb = ISwapRouter(0x8A21F6768C1f8075791D08546Dadf6daA0bE820c);

        //===== Arbitrum Tokens
        arbWEth = IWETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        aUSDC = USDC(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

        {
        //===== Deploy Arbitrum Scripts
        proxyDeployArbitrum = new InfraProxyDeploy();
        dexDeployArbitrum = new DexSwapDeploy();
        childDeployArbitrum = new ChildPoolDeploy();
        conceroDeployArbitrum = new ConceroDeploy();
        orchDeployArbitrum = new OrchestratorDeploy();
        childProxyDeploy = new ChildPoolProxyDeploy();

        //DEPLOY AN DUMMY ORCH
        orchEmptyDst = orchDeployArbitrum.run(
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            1
        );
        childProxy = childProxyDeploy.run(address(orchEmptyDst), ProxyOwner, Tester, "");

        //====== Deploy the proxy with the dummy Orch
        proxyDst = proxyDeployArbitrum.run(address(orchEmptyDst), ProxyOwner, Tester, "");

        proxyInterfaceInfraArb = ITransparentUpgradeableProxy(address(proxyDst));
        proxyInterfaceChild = ITransparentUpgradeableProxy(address(childProxy));

        dexDst = dexDeployArbitrum.run(
            address(proxyDst),
            address(arbWEth)
        );

        conceroDst = conceroDeployArbitrum.run(
            IStorage.FunctionsVariables ({
                subscriptionId: 0, //uint64 _subscriptionId,
                donId: donIdArb,
                functionsRouter: address(functionsRouterArb)
            }),
            arbChainSelector,
            1, //uint _chainIndex,
            linkArb,
            ccipRouterArb,
            address(dexDst),
            address(childProxy),
            address(proxyDst)
        );

        orchDst = orchDeployArbitrum.run(
            address(functionsRouterArb),
            address(dexDst),
            address(conceroDst),
            address(childProxy),
            address(proxyDst),
            1
        );

        child = childDeployArbitrum.run(
            address(proxyDst),
            address(masterProxy),
            address(childProxy),
            linkArb,
            ccipRouterArb,
            baseChainSelector,
            address(aUSDC),
            Tester
        );

        wChild = ConceroChildPool(payable(address(childProxy)));

        //=== Arbitrum Contracts
        vm.makePersistent(address(proxyDst));
        vm.makePersistent(address(dexDst));
        vm.makePersistent(address(child));
        vm.makePersistent(address(conceroDst));
        vm.makePersistent(address(orchDst));
        vm.makePersistent(address(childProxy));
        vm.makePersistent(address(wChild));

        //====== Update the proxy for the correct address
        vm.prank(ProxyOwner);
        proxyInterfaceInfraArb.upgradeToAndCall(address(orchDst), "");
        vm.prank(ProxyOwner);
        proxyInterfaceChild.upgradeToAndCall(address(child), "");

        //====== Wrap the proxy as the implementation
        opDst = Orchestrator(address(proxyDst));

        //====== Set the DEXes routers
        vm.startPrank(defaultSender);
        opDst.setDexRouterAddress(address(uniswapV2Arb), 1);
        opDst.setDexRouterAddress(address(sushiV2Arb), 1);
        opDst.setDexRouterAddress(address(uniswapV3Arb), 1);
        opDst.setDexRouterAddress(address(sushiV3Arb), 1);
        }
    }

    modifier setters(){
        //================ SWITCH CHAINS ====================\\
        //BASE
        vm.selectFork(baseMainFork);

        //====== Setters
        vm.startPrank(Tester);
        wMaster.setPoolsToSend(arbChainSelector, address(childProxy));
        assertEq(wMaster.s_poolToSendTo(arbChainSelector), address(wChild));

        wMaster.setConceroContractSender(arbChainSelector, address(wChild), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(wChild)), 1);

        wMaster.setConceroContractSender(arbChainSelector, address(conceroDst), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(conceroDst)), 1);
        vm.stopPrank();

        vm.startPrank(address(subOwner));
        functionsRouterBase.addConsumer(14, address(op));
        functionsRouterBase.addConsumer(14, address(wMaster));
        functionsRouterBase.addConsumer(14, address(automation));
        vm.stopPrank();

        //================ SWITCH CHAINS ====================\\
        //ARBITRUM
        vm.selectFork(arbitrumMainFork);
        //====== Setters
        vm.startPrank(Tester);

        wChild.setConceroContractSender(baseChainSelector, address(wMaster), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(wMaster)), 1);

        wChild.setConceroContractSender(baseChainSelector, address(concero), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(concero)), 1);

        vm.stopPrank();

        vm.startPrank(address(subOwner));
        functionsRouterArb.addConsumer(22, address(opDst));
        functionsRouterArb.addConsumer(22, address(wChild));
        vm.stopPrank();
        _;
    }

    function helper() public {
        vm.selectFork(baseMainFork);

        vm.deal(User, INITIAL_BALANCE);
        vm.deal(LP, LP_INITIAL_BALANCE);

        vm.startPrank(User);
        wEth.deposit{value: INITIAL_BALANCE}();
        vm.stopPrank();

        vm.startPrank(LP);
        wEth.deposit{value: LP_INITIAL_BALANCE}();
        vm.stopPrank();

        assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
        assertEq(wEth.balanceOf(LP), LP_INITIAL_BALANCE);
    }

    function test_CanSelectFork() public {
        // select the fork
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);
        vm.selectFork(arbitrumMainFork);
        assertEq(vm.activeFork(), arbitrumMainFork);
    }

    //Moved the logic to setUp to ease the tests
    function test_canUpgradeTheImplementation() public {
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

        vm.startPrank(ProxyOwner);
        proxyInterfaceInfra.upgradeToAndCall(address(SAFE_LOCK), "");

        vm.stopPrank();
    }

    /// TEST SAFE LOCK ///
    error Proxy_ContractPaused();
    function test_safeLockAndRevertOnCall() public {
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

        vm.startPrank(ProxyOwner);

        proxyInterfaceInfra.upgradeToAndCall(address(SAFE_LOCK), "");

        vm.stopPrank();

        op = Orchestrator(address(proxy));

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(concero), amountIn);

        DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
                        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);

        //==== Initiate transaction
        vm.expectRevert(abi.encodeWithSelector(Proxy_ContractPaused.selector));
        op.swap(swapData, User);
    }

    function test_AdminCanUpdatedImplementationAfterSafeLock() public {
        //====== Chose the Fork Network
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

        vm.startPrank(ProxyOwner);
        //====== Checks for the initial implementation
        // assertEq(proxy.implementation(), address(orch));

        //====== Upgrades it to SAFE_LOCK
        proxyInterfaceInfra.upgradeToAndCall(address(SAFE_LOCK), "");

        //====== Verify if the upgrade happen as expected
        // assertEq(proxy.implementation(), address(SAFE_LOCK));

        //====== Upgrades it again to a valid address
        proxyInterfaceInfra.upgradeToAndCall(address(orch), "");

        //====== Checks if the upgrade happens as expected
        // assertEq(proxy.implementation(), address(orch));

        vm.stopPrank();
    }
}
