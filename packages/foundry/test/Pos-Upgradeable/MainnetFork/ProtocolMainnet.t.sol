// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//Foundry
import {Test, console2} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

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
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
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

contract ProtocolMainnet is Test {
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
    bytes32 etherHashSum = 0x984202f6c36a048a80e993557555488e5ae13ff86f2dfbcde698aacd0a7d4eb4;
    bytes32 hashSum = 0x06a7e0b6224a17f3938fef1f9ea5c3de949134a66cf8cb8483b76449714a4504;
    uint64 donVersion = 1720426529;
    uint8 slotId = 3;

    //Arb Mainnet variables
    address linkArb = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address ccipRouterArb = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    FunctionsRouter functionsRouterArb = FunctionsRouter(0x97083E831F8F0638855e2A515c90EdCF158DF238);
    bytes32 donIdArb = 0x66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000;

    address ProxyOwner = makeAddr("ProxyOwner");
    address Tester = makeAddr("Tester");
    address User = makeAddr("User");
    address Messenger = 0x11111003F38DfB073C6FeE2F5B35A0e57dAc4715;
    address LP = makeAddr("LiquidityProvider");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address subOwner = 0xddDd5f804B9D293dce8819d232e8D76381605a62;

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
        proxy = proxyDeployBase.run(address(orchEmpty), ProxyOwner, "");
        masterProxy = masterProxyDeploy.run(address(orchEmpty), ProxyOwner, "");
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
                subscriptionId: 14, //uint64 _subscriptionId,
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
        uniswapV3Arb = ISwapRouter02(0xE592427A0AEce92De3Edee1F18E0157C05861564);
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
        childProxy = childProxyDeploy.run(address(orchEmptyDst), ProxyOwner, "");

        //====== Deploy the proxy with the dummy Orch
        proxyDst = proxyDeployArbitrum.run(address(orchEmptyDst), ProxyOwner, "");

        proxyInterfaceInfraArb = ITransparentUpgradeableProxy(address(proxyDst));
        proxyInterfaceChild = ITransparentUpgradeableProxy(address(childProxy));

        dexDst = dexDeployArbitrum.run(
            address(proxyDst),
            address(arbWEth)
        );

        conceroDst = conceroDeployArbitrum.run(
            IStorage.FunctionsVariables ({
                subscriptionId: 22, //uint64 _subscriptionId,
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

    //////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// HELPERS MODULE /////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    modifier setters(){
        //================ SWITCH CHAINS ====================\\
        //BASE
        vm.selectFork(baseMainFork);

        //====== Setters
        ///== Pools
        vm.startPrank(Tester);
        wMaster.setPoolsToSend(arbChainSelector, address(childProxy));
        assertEq(wMaster.s_poolToSendTo(arbChainSelector), address(wChild));

        wMaster.setConceroContractSender(arbChainSelector, address(wChild), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(wChild)), 1);

        wMaster.setConceroContractSender(arbChainSelector, address(conceroDst), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(conceroDst)), 1);

        wMaster.setDonHostedSecretsSlotId(slotId);

        wMaster.setDonHostedSecretsVersion(donVersion);

        wMaster.setHashSum(hashSum);

        wMaster.setEthersHashSum(etherHashSum);
        vm.stopPrank();

        ///== Infra
        vm.startPrank(defaultSender);
        op.setDstConceroPool(arbChainSelector, address(wChild));
        assertEq(op.s_poolReceiver(arbChainSelector), address(wChild));

        op.setConceroContract(arbChainSelector, address(opDst));
        assertEq(op.s_conceroContracts(arbChainSelector), address(opDst));
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
        ///== Pools
        vm.startPrank(Tester);
        wChild.setConceroContractSender(baseChainSelector, address(wMaster), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(wMaster)), 1);

        wChild.setConceroContractSender(baseChainSelector, address(concero), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(concero)), 1);
        vm.stopPrank();

        ///== Infra
        vm.startPrank(defaultSender);
        opDst.setConceroContract(baseChainSelector, address(op));
        assertEq(opDst.s_conceroContracts(baseChainSelector), address(op));

        opDst.setDstConceroPool(baseChainSelector, address(wMaster));
        assertEq(opDst.s_poolReceiver(baseChainSelector), address(wMaster));
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

    event FirstLegDone();
    // function swapUniV2LikeHelper() public {
    //     vm.deal(User, INITIAL_BALANCE);
    //     vm.deal(LP, LP_INITIAL_BALANCE);

    //     vm.startPrank(User);
    //     wEth.deposit{value: INITIAL_BALANCE}();
    //     vm.stopPrank();

    //     vm.startPrank(LP);
    //     wEth.deposit{value: LP_INITIAL_BALANCE}();
    //     vm.stopPrank();

    //     assertEq(wEth.balanceOf(User), INITIAL_BALANCE);
    //     assertEq(wEth.balanceOf(LP), LP_INITIAL_BALANCE);

    //     uint amountIn = LP_INITIAL_BALANCE;
    //     uint amountOutMin = 4 *10**6;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(mUSDC);
    //     uint deadline = block.timestamp + 1800;

    //     vm.startPrank(LP);

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(uniswapV2, path, deadline)
    //                     });

    //     // ==== Approve Transfer
    //     wEth.approve(address(op), amountIn);

    //     //==== Initiate transaction
    //     op.swap(swapData, LP);
    //     vm.stopPrank();

    //     emit FirstLegDone();
    // }

    ////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// PROXY MODULE /////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

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
    // function test_safeLockAndRevertOnCall() public {
    //     vm.selectFork(baseMainFork);
    //     assertEq(vm.activeFork(), baseMainFork);

    //     vm.startPrank(ProxyOwner);

    //     proxyInterfaceInfra.upgradeToAndCall(address(SAFE_LOCK), "");

    //     vm.stopPrank();

    //     op = Orchestrator(address(proxy));

    //     uint amountIn = 1*10**17;
    //     uint amountOutMin = 350*10**5;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(mUSDC);
    //     uint deadline = block.timestamp + 1800;

    //     vm.startPrank(User);
    //     wEth.approve(address(concero), amountIn);

    //     DexSwap.SwapData[] memory swapData = new DexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //                     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), 0.1 ether);

    //     //==== Initiate transaction
    //     vm.expectRevert(abi.encodeWithSelector(Proxy_ContractPaused.selector));
    //     op.swap(swapData, User);
    // }

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

    ///////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// SWAPPING MODULE /////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////
    error DexSwap_CallableOnlyByOwner(address, address);
    event DexSwap_RemovingDust(address, uint256);
    error DexSwap_EmptyDexData();
    error Orchestrator_UnableToCompleteDelegateCall(bytes);
    error Orchestrator_InvalidSwapData();
    // function test_swapUniV2LikeMock() public {
    //     helper();

    //     uint amountIn = 1*10**16;
    //     uint amountOutMin = 250*10**5;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(mUSDC);
    //     address to = User;
    //     uint deadline = block.timestamp + 1800;

    //     //=================================== Successful Leg =========================================\\

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     //==== Initiate transaction
    //     op.swap(swapData, to);

    //     assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
    //     assertEq(wEth.balanceOf(address(op)), amountIn / 1000);
    //     assertTrue(mUSDC.balanceOf(User) >= amountOutMin);
    //     vm.stopPrank();
        
    //     //=================================== Revert Leg =========================================\\

    //     ///==== Invalid Path

    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(mUSDC),
    //                         fromAmount: 1*10**6,
    //                         toToken: address(wEth),
    //                         toAmount: 1*10**8,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     mUSDC.approve(address(op), 1*10**6);

    //     bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);

    //     //==== Initiate transaction
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
    //     op.swap(swapData, to);
    //     vm.stopPrank();

    //     ///==== Invalid Router
        
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(User, path, deadline)
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     //==== Initiate transaction
    //     bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
    //     op.swap(swapData, to);
    //     vm.stopPrank();

    //     ///==== Invalid dexData
        
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: ""
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     //==== Initiate transaction
    //     bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
    //     op.swap(swapData, to);
    //     vm.stopPrank();
    // }

    // function test_swapUniV2LikeFoTMock() public {
    //     helper();

    //     uint amountIn = 1*10**17;
    //     uint amountOutMin = 350*10**5;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(mUSDC);
    //     address to = User;
    //     uint deadline = block.timestamp + 1800;

    //     vm.startPrank(User);
    //     wEth.approve(address(concero), amountIn);

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2FoT,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), 0.1 ether);

    //     //==== Initiate transaction
    //     op.swap(swapData, to);

    //     assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
    //     assertEq(wEth.balanceOf(address(op)), 100000000000000);
    //     assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOutMin);

    //     ////================================= Revert =============================\\\\\
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2FoT,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: ""
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), 0.1 ether);
    //     bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
    //     op.swap(swapData, to);

    //     ////================================== REVERT ====================================\\\\
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2FoT,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(User, path, deadline)
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), 0.1 ether);
    //     bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
    //     op.swap(swapData, to);

    //     ////================================== REVERT ====================================\\\\
    //     path[0] = address(mUSDC);
    //     path[1] = address(mUSDC);

    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2FoT,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), 0.1 ether);
    //     bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
    //     op.swap(swapData, to);
    // }

    // function test_swapSushiV3SingleMock() public {
    //     helper();
    //     uint256 amountIn = 1*10**17;
    //     uint256 amountOut = 350*10*6;
    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.SushiV3Single,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: 1*10**5,
    //                         toAmountMin: amountOut,
    //                         dexData: abi.encode(sushiV3, 500, block.timestamp + 1800, 0)
    //                     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), 1 ether);

    //     op.swap(swapData, User);

    //     assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
    //     assertEq(wEth.balanceOf(address(op)), 100000000000000);
    //     assertTrue(mUSDC.balanceOf(address(User))> USDC_INITIAL_BALANCE + amountOut);

    //     //=================================== Revert Leg =========================================\\
        
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.SushiV3Single,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: 1*10**5,
    //                         toAmountMin: amountOut,
    //                         dexData: abi.encode(User, 500, block.timestamp + 1800, 0)
    //                     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), 1 ether);
    //     bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
    //     op.swap(swapData, User);
    //     vm.stopPrank();

    //     //=================================== Revert Leg =========================================\\
        
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.SushiV3Single,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: 1*10**5,
    //                         toAmountMin: amountOut,
    //                         dexData: ""
    //                     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), 1 ether);
    //     bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
    //     op.swap(swapData, User);
    //     vm.stopPrank();
    // }

    function test_swapUniV3SingleMock() public {
        helper();
        assertEq(wEth.balanceOf(address(dex)), 0);

        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, 500, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        op.swap(swapData, User);

        assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

        //=================================== Revert Leg =========================================\\

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, 500, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);

        //=================================== Revert Leg =========================================\\

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);
    }

    function test_swapEtherUniV3SingleBase() public {
        vm.selectFork(baseMainFork);
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        vm.deal(User, amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, 500, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);

        op.swap{value: amountIn}(swapData, User);

        assertEq(address(op).balance, 100000000000000);
        assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    function test_swapEtherUniV3SingleArb() public {
        vm.selectFork(arbitrumMainFork);
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 350*10*6;

        vm.deal(User, amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(aUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3Arb, 500, 0, block.timestamp + 1800)
        });

        vm.startPrank(User);

        opDst.swap{value: amountIn}(swapData, User);

        assertEq(address(opDst).balance, 100000000000000);
        assertTrue(aUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);
    }

    // function test_swapSushiV3MultiMock() public {
    //     helper();

    //     uint24 poolFee = 500;
    //     uint256 amountIn = 1*10**17;
    //     uint256 amountOut = 1*10**16;

    //     bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.SushiV3Multi,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(wEth),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(sushiV3, path, block.timestamp + 300)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

    //     op.swap(swapData, User);

    //     assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
    //     assertEq(wEth.balanceOf(address(op)), 100000000000000);
    //     assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);

    //     //=================================== Revert Leg =========================================\\
        
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.SushiV3Multi,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(wEth),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(User, path, block.timestamp + 300)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
    //     op.swap(swapData, User);

    //     //=================================== Revert Leg =========================================\\
        
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.SushiV3Multi,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(wEth),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: ""
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
    //     op.swap(swapData, User);
    // }

    error DexSwap_InvalidPath();
    error DexSwap_RouterNotAllowed();
    // function test_revertSwapSushiV3MultiMockInvalidPath() public {
    //     helper();

    //     uint24 poolFee = 500;
    //     uint256 amountIn = 1*10**17;
    //     uint256 amountOut = 1*10**16;

    //     bytes memory path = abi.encodePacked(mUSDC, poolFee, wEth, poolFee, mUSDC);

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.SushiV3Multi,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(wEth),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(sushiV3, path, block.timestamp + 300)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
    //     op.swap(swapData, User);

    //     vm.stopPrank();
    // }

    function test_swapUniV3MultiMock() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 300*10*6;

        bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(wEth),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        op.swap(swapData, User);

        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn);
        assertEq(wEth.balanceOf(address(op)), 100000000000000);
        assertTrue(wEth.balanceOf(address(User)) >= INITIAL_BALANCE - amountIn + amountOut);

        ///===== Revert because of toToken
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
        op.swap(swapData, User);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(User, path, block.timestamp + 1800)
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
        op.swap(swapData, User);

        //=================================== Revert Leg =========================================\\
        
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: ""
        });

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
        op.swap(swapData, User);
    }

    function test_swapEtherUniV3MultiMock() public {
        vm.selectFork(baseMainFork);
        vm.deal(User, 1*10**18);

        uint24 poolFee = 500;
        uint256 amountIn = 1*10**17;
        uint256 amountOut = 1*10**16;

        bytes memory path = abi.encodePacked(wEth, poolFee, mUSDC, poolFee, wEth);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(0),
            fromAmount: amountIn,
            toToken: address(wEth),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path, block.timestamp + 1800)
        });

        vm.startPrank(User);
        op.swap{value: amountIn}(swapData, User);

        assertEq(User.balance, 1*10**18 - amountIn);
        assertEq(address(op).balance, 100000000000000);
        assertTrue(wEth.balanceOf(User) > amountOut);
    }

    function test_revertSwapUniV3MultiMockInvalidPath() public {
        helper();

        uint24 poolFee = 500;
        uint256 amountIn = 350*10*6;
        uint256 amountOut = 1*10**17;

        bytes memory path = abi.encodePacked(mUSDC, poolFee, wEth, poolFee, mUSDC);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Multi,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV3, path)
        });


        vm.startPrank(User);

        wEth.approve(address(op), amountIn);
        bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
        op.swap(swapData, User);
        
        vm.stopPrank();
    }

    // function test_swapDromeMock() public {
    //     helper();

    //     assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

    //     uint256 amountIn = 1*10**17;
    //     uint256 amountOut = 350*10*6;

    //     IRouter.Route[] memory route = new IRouter.Route[](1);

    //     IRouter.Route memory routes = IRouter.Route({
    //         from: address(wEth),
    //         to: address(mUSDC),
    //         stable: false,
    //         factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
    //     });

    //     route[0] = routes;

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.Aerodrome,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     op.swap(swapData, User);

    //     assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
    //     assertEq(wEth.balanceOf(address(op)), 100000000000000);
    //     assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

    //     ///============================= Invalid Path Revert
        
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.Aerodrome,
    //         fromToken: address(mUSDC),
    //         fromAmount: 350*10**5,
    //         toToken: address(wEth),
    //         toAmount: 1*10**8,
    //         toAmountMin: 1*10**8,
    //         dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     mUSDC.approve(address(op), 350*10**5);
    //     bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
    //     op.swap(swapData, User);

    //     ///============================= Empty Dex Data Revert

    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.Aerodrome,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: ""
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
    //     op.swap(swapData, User);

    //     ///============================= Empty Dex Data Revert

    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.Aerodrome,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(User, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
    //     op.swap(swapData, User);
    // }

    // function test_swapDromeFoTMock() public {
    //     helper();

    //     assertEq(wEth.balanceOf(User), INITIAL_BALANCE);

    //     uint256 amountIn = 1*10**17;
    //     uint256 amountOut = 350*10*6;

    //     IRouter.Route[] memory route = new IRouter.Route[](1);

    //     IRouter.Route memory routes = IRouter.Route({
    //         from: address(wEth),
    //         to: address(mUSDC),
    //         stable: false,
    //         factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
    //     });

    //     route[0] = routes;

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.AerodromeFoT,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     op.swap(swapData, User);

    //     assertEq(wEth.balanceOf(address(User)), INITIAL_BALANCE - amountIn);
    //     assertEq(wEth.balanceOf(address(op)), 100000000000000);
    //     assertTrue(mUSDC.balanceOf(address(User)) > USDC_INITIAL_BALANCE + amountOut);

    //     ///============================= Invalid Path Revert
        
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.Aerodrome,
    //         fromToken: address(mUSDC),
    //         fromAmount: 350*10**5,
    //         toToken: address(wEth),
    //         toAmount: 1*10**8,
    //         toAmountMin: 1*10**8,
    //         dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     mUSDC.approve(address(op), 350*10**5);
    //     bytes memory encodedError = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, encodedError));
    //     op.swap(swapData, User);

    //     ///============================= Empty Dex Data
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.AerodromeFoT,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: ""
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory emptyDexData = abi.encodeWithSelector(DexSwap_EmptyDexData.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, emptyDexData));
    //     op.swap(swapData, User);

    //     ///============================= Router Not allowed Revert
    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.AerodromeFoT,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(User, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory routerNotAllowed = abi.encodeWithSelector(DexSwap_RouterNotAllowed.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, routerNotAllowed));
    //     op.swap(swapData, User);

    //     ///============================= Router Not allowed Revert

    //     IRouter.Route memory routesTwo = IRouter.Route({
    //         from: address(mUSDC),
    //         to: address(mUSDC),
    //         stable: false,
    //         factory: 0x420DD381b31aEf6683db6B902084cB0FFECe40Da
    //     });

    //     route[0] = routesTwo;

    //     swapData[0] = IDexSwap.SwapData({
    //         dexType: IDexSwap.DexType.AerodromeFoT,
    //         fromToken: address(wEth),
    //         fromAmount: amountIn,
    //         toToken: address(mUSDC),
    //         toAmount: amountOut,
    //         toAmountMin: amountOut,
    //         dexData: abi.encode(aerodromeRouter, route, block.timestamp + 1800)
    //     });

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);
    //     bytes memory invalidPath = abi.encodeWithSelector(DexSwap_InvalidPath.selector);
    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, invalidPath));
    //     op.swap(swapData, User);
    // }

    // function test_customMultiHopFunctionalitySuccess() public {
    //     helper();

    //     uint amountIn = 1*10**17;
    //     uint amountOutMin = 350*10**5;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(mUSDC);
    //     uint deadline = block.timestamp + 1800;

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](2);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     //==== Initiate transaction

    //     /////=============== TEST CHAINED TX =====================\\\\\        
        
    //     amountIn = 350*10**5;
    //     amountOutMin = 1*10**16;
    //     path = new address[](2);
    //     path[0] = address(mUSDC);
    //     path[1] = address(wEth);

    //     swapData[1] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(mUSDC),
    //                         fromAmount: amountIn,
    //                         toToken: address(wEth),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     //==== Initiate transaction
    //     op.swap(swapData, User);
    // }

    error DexSwap_SwapDataNotChained(address, address);
    // function test_customMultiHopFunctionalityRevert() public {
    //     helper();

    //     uint amountIn = 1*10**17;
    //     uint amountOutMin = 350*10**5;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(mUSDC);
    //     uint deadline = block.timestamp + 1800;

    //     vm.startPrank(User);
    //     wEth.approve(address(op), amountIn);

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](2);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     /////=============== TEST CHAINED TX =====================\\\\\
    //     swapData[1] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(mUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(sushiV2, path, deadline)
    //     });

    //     //==== Initiate transaction
    //     bytes memory notChained = abi.encodeWithSelector(DexSwap_SwapDataNotChained.selector, address(mUSDC), address(wEth));

    //     vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, notChained));
    //     op.swap(swapData, User);
    // }

    error DexSwap_ItsNotOrchestrator(address);
    function test_revertConceroEntry() public {
        
        helper();

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        vm.expectRevert(abi.encodeWithSelector(DexSwap_ItsNotOrchestrator.selector, address(dex)));
        dex.conceroEntry(swapData, User);
        
        IDexSwap.SwapData[] memory emptyData = new IDexSwap.SwapData[](0);

        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swap(emptyData, User);
        
        IDexSwap.SwapData[] memory fullData = new IDexSwap.SwapData[](6);
        fullData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[1] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[2] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[3] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[4] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });
        fullData[5] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(sushiV2, path, deadline)
        });

        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swap(fullData, User);
    }

    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    //This test only work with USDC Mainnet address on Storage::getToken function.
    error ParentPool_AmountBelowMinimum(uint256);
    error ParentPool_MaxCapReached(uint256);
    event ParentPool_MasterPoolCapUpdated(uint256 _newCap);
    event ParentPool_SuccessfulDeposited(address, uint256 , address);
    event ParentPool_MessageSent(bytes32, uint64, address, address, uint256);
    ///=== Functions Errors
    error OnlyRouterCanFulfill();
    error EmptySource();
    error EmptySecrets();
    error EmptyArgs();
    error NoInlineSecrets();
    // function test_LiquidityProvidersDepositAndOpenARequest() public setters {
    //     vm.selectFork(baseMainFork);

    //     swapUniV2LikeHelper();

    //     uint256 lpBalance = mUSDC.balanceOf(LP);
    //     uint256 depositLowAmount = 10*10**6;

    //     //======= LP Deposits Low Amount of USDC on the Main Pool to revert on Min Amount
    //     vm.startPrank(LP);
    //     mUSDC.approve(address(wMaster), depositLowAmount);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_AmountBelowMinimum.selector, 100*10**6));
    //     wMaster.depositLiquidity(depositLowAmount);
    //     vm.stopPrank();

    //     //======= Increase the CAP
    //     vm.expectEmit();
    //     vm.prank(Tester);
    //     emit ParentPool_MasterPoolCapUpdated(50*10**6);
    //     wMaster.setPoolCap(50*10**6);

    //     //======= LP Deposits enough to go through, but revert on max Cap
    //     uint256 depositEnoughAmount = 100*10**6;

    //     vm.startPrank(LP);
    //     mUSDC.approve(address(wMaster), depositEnoughAmount);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_MaxCapReached.selector, 50*10**6));
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     vm.stopPrank();

    //     //======= Increase the CAP
    //     vm.expectEmit();
    //     vm.prank(Tester);
    //     emit ParentPool_MasterPoolCapUpdated(1000*10**6);
    //     wMaster.setPoolCap(1000*10**6);

    //     //======= LP Deposits Successfully
    //     vm.startPrank(LP);
    //     mUSDC.approve(address(wMaster), depositEnoughAmount);
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     // ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumMainFork);
    //     vm.stopPrank();

    //     //======= Check LP balance
    //     assertEq(mUSDC.balanceOf(LP), lpBalance - depositEnoughAmount);

    //     //======= We check the pool balance;
    //                 //Here, the LP Fees will be compounding directly for the LP address
    //     uint256 poolBalance = mUSDC.balanceOf(address(wMaster));
    //     assertEq(poolBalance, depositEnoughAmount/2);

    //     uint256 lpTokenUserBalance = lp.balanceOf(LP);

    //     //======= Request Withdraw without any accrued fee
    //     vm.startPrank(LP);
    //     wMaster.startWithdrawal(lpTokenUserBalance);
    //     vm.stopPrank();

    //     //======= No operations are made. Advance time
    //     vm.warp(block.timestamp + 7 days);

    //     //======= Withdraw after the lock period and cross-chain transference
    //     vm.startPrank(LP);
    //     lp.approve(address(pool), lpTokenUserBalance);
    //     wMaster.completeWithdrawal();
    //     vm.stopPrank();

    //     // //======= Check LP balance
    //     assertEq(mUSDC.balanceOf(LP), lpBalance);
    // }

    ////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// BRIDGE MODULE ///////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////
    function test_swapAndBridgeMainnet() public setters {
        vm.selectFork(arbitrumMainFork);
        assertEq(aUSDC.balanceOf(address(User)), 0);

        vm.selectFork(baseMainFork);

        helper();

        ///////////////////////// SRC swap /////////////////////////
        assertEq(wEth.balanceOf(address(op)), 0);

        uint256 amountInSrc = 1*10**17;
        uint256 amountOutSrc = 350*10*6;

        IDexSwap.SwapData[] memory swapDataSrc = new IDexSwap.SwapData[](1);

        swapDataSrc[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(wEth),
            fromAmount: amountInSrc,
            toToken: address(mUSDC),
            toAmount: amountOutSrc,
            toAmountMin: amountOutSrc,
            dexData: abi.encode(uniswapV3, 500, 0, block.timestamp + 1800)
        });

        ///////////////////////// Bridge /////////////////////////
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: amountOutSrc,
            dstChainSelector: arbChainSelector,
            receiver: User
        });

        ///////////////////////// DST Swap /////////////////////////
        uint256 amountInDst = 350*10*6;
        uint256 amountOutDst = 1*10**16;

        IDexSwap.SwapData[] memory swapDataDst = new IDexSwap.SwapData[](1);

        swapDataDst[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(aUSDC),
            fromAmount: 0,
            toToken: address(wEth),
            toAmount: amountOutDst,
            toAmountMin: amountOutDst,
            dexData: abi.encode(uniswapV3Arb, 500, 0, block.timestamp + 1800)
        });

        ///======= Revert Over fromAmount === 0
        vm.startPrank(User);
        wEth.approve(address(op), amountInSrc);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swapAndBridge(bridgeData, swapDataSrc, swapDataDst);

        swapDataDst[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(aUSDC),
            fromAmount: amountInDst,
            toToken: address(wEth),
            toAmount: amountOutDst,
            toAmountMin: 0,
            dexData: abi.encode(uniswapV3Arb, 500, 0, block.timestamp + 1800)
        });

        ///======= Revert Over toAmountMin === 0
        vm.startPrank(User);
        wEth.approve(address(op), amountInSrc);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swapAndBridge(bridgeData, swapDataSrc, swapDataDst);

        IDexSwap.SwapData[] memory swapDataDstMulti = new IDexSwap.SwapData[](2);

        swapDataDstMulti[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(aUSDC),
            fromAmount: amountInDst,
            toToken: address(wEth),
            toAmount: amountOutDst,
            toAmountMin: amountOutDst,
            dexData: abi.encode(uniswapV3Arb, 500, 0, block.timestamp + 1800)
        });

        swapDataDstMulti[1] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV3Single,
            fromToken: address(aUSDC),
            fromAmount: amountInDst,
            toToken: address(wEth),
            toAmount: amountOutDst,
            toAmountMin: amountOutDst,
            dexData: abi.encode(uniswapV3Arb, 500, 0, block.timestamp + 1800)
        });

        ///======= Revert Over Destination Multi-Hops === 0
        vm.startPrank(User);
        wEth.approve(address(op), amountInSrc);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swapAndBridge(bridgeData, swapDataSrc, swapDataDstMulti);
    }
}
