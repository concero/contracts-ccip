// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//Foundry
import {Test, console} from "forge-std/Test.sol";

//Master & Infra Contracts
import {DexSwap} from "contracts/DexSwap.sol";
import {ParentPool} from "contracts/ParentPool.sol";
import {Concero} from "contracts/Concero.sol";
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

//Parent & Infra Scripts
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
import {DEXMock} from "../../Mocks/DEXMock.sol";
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

contract ProtocolTestnet is Test {
    //==== Instantiate Base Contracts
    DexSwap public dex;
    ParentPool public pool;
    Concero public concero;
    Orchestrator public orch;
    Orchestrator public orchEmpty;
    InfraProxy public proxy;
    LPToken public lp;
    ConceroAutomation public automation;
    ParentPoolProxy masterProxy;
    ITransparentUpgradeableProxy proxyInterfaceInfra;
    ITransparentUpgradeableProxy proxyInterfaceMaster;
    DEXMock public mockBase;

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
    Concero public conceroDst;
    Orchestrator public orchDst;
    Orchestrator public orchEmptyDst;
    InfraProxy public proxyDst;
    ChildPoolProxy public childProxy;
    ITransparentUpgradeableProxy proxyInterfaceInfraArb;
    ITransparentUpgradeableProxy proxyInterfaceChild;
    DEXMock public mockArb;

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

    //==== Instantiate Chainlink Forked CCIP
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint64 baseChainSelector = 10344971235874465080;
    uint64 arbChainSelector = 3478487238524512106;

    //Base Testnet variables
    address linkBase = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address ccipRouterBase = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;
    FunctionsRouter functionsRouterBase = FunctionsRouter(0xf9B8fc078197181C841c296C876945aaa425B278);
    bytes32 donIdBase = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;
    uint64 subscriptionIdBase = 16;
    address linkOwnerBase = 0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC;
    address ccipBnM = 0x88A2d74F47a237a62e7A51cdDa67270CE381555e;
    address ccipBnMArb = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D;

    //Arb Testnet variables
    address linkArb = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;
    address ccipRouterArb = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    FunctionsRouter functionsRouterArb = FunctionsRouter(0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C);
    bytes32 donIdArb = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;
    uint64 subscriptionIdArb = 53;

    address ProxyOwner = makeAddr("ProxyOwner");
    address Tester = makeAddr("Tester");
    address User = makeAddr("User");
    address Messenger = makeAddr("Messenger");
    address LP = makeAddr("LiquidityProvider");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address subOwnerBase = 0x007E2e8D8CF1C50291943a805b7CdAe8ae8EfaaE;
    address subOwnerArb = 0xDddDDb8a8E41C194ac6542a0Ad7bA663A72741E0;

    uint256 baseTestFork;
    uint256 arbitrumTestFork;
    string BASE_TESTNET_RPC_URL = vm.envString("BASE_TESTNET_RPC_URL");
    string ARB_TESTNET_RPC_URL = vm.envString("ARB_TESTNET_RPC_URL");
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant LINK_BALANCE = 1 ether;
    uint256 constant USDC_INITIAL_BALANCE = 10 * 10**6;
    uint256 constant LP_INITIAL_BALANCE = 2 ether;
    ERC721 SAFE_LOCK;

    function setUp() public {
        baseTestFork = vm.createSelectFork(BASE_TESTNET_RPC_URL);
        arbitrumTestFork = vm.createFork(ARB_TESTNET_RPC_URL);
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.selectFork(baseTestFork);

        wEth = IWETH(0x4200000000000000000000000000000000000006);
        AERO = ERC20Mock(0x940181a94A35A4569E4529A3CDfB74e38FD98631);
        SAFE_LOCK = ERC721(0x048B9d899e5c5dABA4361Dd7ae5E24A93b93b535);
        mUSDC = new USDC("Mock USDC", "USDC", Tester, 1000 * 10**6);

        dexDeployBase = new DexSwapDeploy();
        poolDeployBase = new ParentPoolDeploy();
        conceroDeployBase = new ConceroDeploy();
        orchDeployBase = new OrchestratorDeploy();
        proxyDeployBase = new InfraProxyDeploy();
        lpDeployBase = new LPTokenDeploy();
        autoDeployBase = new AutomationDeploy();
        masterProxyDeploy = new ParentPoolProxyDeploy();

        {
        mockBase = new DEXMock();

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
            subscriptionIdBase, //_subscriptionId
            2, //_slotId
            0, //_secretsVersion
            0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124, //_srcJsHashSum
            0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124, //_ethersHashSum
            address(functionsRouterBase), //_router,
            address(masterProxy),
            Tester
        );

        // DexSwap Contract
        dex = dexDeployBase.run(address(proxy), address(wEth));

        concero = conceroDeployBase.run(
            IStorage.FunctionsVariables ({
                subscriptionId: subscriptionIdBase, //uint64 _subscriptionId,
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
            subscriptionIdBase,
            address(functionsRouterBase),
            ccipRouterBase,
            address(ccipBnM),
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
        vm.prank(defaultSender);
        op.setDexRouterAddress(address(mockBase), 1);
        }

        vm.prank(linkOwnerBase);
        LinkToken(linkBase).grantMintRole(Tester);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(op), 10*10**18);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(wMaster), 10*10**18);

        vm.prank(0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC);
        ERC20Mock(ccipBnM).mint(address(LP), 1000 * 10**18);

        /////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
        //================ SWITCH CHAINS ====================\\
        ///////////////////////////////////////////////////////
        vm.selectFork(arbitrumTestFork);

        //===== Arbitrum Tokens
        arbWEth = IWETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        aUSDC = USDC(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d);

        {
        //===== Deploy Arbitrum Scripts
        proxyDeployArbitrum = new InfraProxyDeploy();
        dexDeployArbitrum = new DexSwapDeploy();
        childDeployArbitrum = new ChildPoolDeploy();
        conceroDeployArbitrum = new ConceroDeploy();
        orchDeployArbitrum = new OrchestratorDeploy();
        childProxyDeploy = new ChildPoolProxyDeploy();

        mockArb = new DEXMock();

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
                subscriptionId: subscriptionIdArb, //uint64 _subscriptionId,
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
            address(ccipBnMArb),
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
        vm.prank(defaultSender);
        opDst.setDexRouterAddress(address(mockArb), 1);
        }
    }

    modifier setters(){
        //================ SWITCH CHAINS ====================\\
        //BASE
        vm.selectFork(baseTestFork);

        //====== Setters
        vm.startPrank(Tester);
        wMaster.setPoolsToSend(arbChainSelector, address(childProxy));
        assertEq(wMaster.s_poolToSendTo(arbChainSelector), address(wChild));

        wMaster.setConceroContractSender(arbChainSelector, address(wChild), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(wChild)), 1);

        wMaster.setConceroContractSender(arbChainSelector, address(conceroDst), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(conceroDst)), 1);
        vm.stopPrank();

        vm.startPrank(address(subOwnerBase));
        functionsRouterBase.addConsumer(14, address(op));
        functionsRouterBase.addConsumer(14, address(wMaster));
        functionsRouterBase.addConsumer(14, address(automation));
        vm.stopPrank();

        //================ SWITCH CHAINS ====================\\
        //ARBITRUM
        vm.selectFork(arbitrumTestFork);
        //====== Setters
        vm.startPrank(Tester);
        wChild.setConceroContractSender(baseChainSelector, address(wMaster), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(wMaster)), 1);

        wChild.setConceroContractSender(baseChainSelector, address(concero), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(concero)), 1);
        vm.stopPrank();

        vm.startPrank(address(subOwnerArb));
        functionsRouterArb.addConsumer(53, address(opDst));
        functionsRouterArb.addConsumer(53, address(wChild));
        vm.stopPrank();

        vm.prank(0x4281eCF07378Ee595C564a59048801330f3084eE);
        IERC20(linkArb).transfer(address(wChild), 1*10**18);
        _;
    }

    function helper() public {
        vm.selectFork(baseTestFork);

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
}
