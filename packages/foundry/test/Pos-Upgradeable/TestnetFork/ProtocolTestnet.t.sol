// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//Foundry
import {Test, console} from "forge-std/Test.sol";

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
    ConceroBridge public concero;
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
    ConceroBridge public conceroDst;
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
    USDC public tUSDC;
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
    address registryAddress = 0x8B1565DbAF0577F2F3b474334b068C95687f4FcE;

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
    address subOwnerBase = 0xDddDDb8a8E41C194ac6542a0Ad7bA663A72741E0;
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
        tUSDC = USDC(0x036CbD53842c5426634e7929541eC2318f3dCF7e);

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
        uint256 lastGasPrice = 5767529;
        uint256 latestLinkUsdcRate = 13_560_000_000_000_000_000;
        uint256 latestNativeUsdcRate = 3_383_730_000_000_000_000_000;
        uint256 latestLinkNativeRate = 40091515;
        bytes memory data = abi.encodeWithSignature("initialize(uint64,uint256,uint256,uint256,uint256)", arbChainSelector, lastGasPrice, latestLinkUsdcRate, latestNativeUsdcRate, latestLinkNativeRate);

        vm.prank(ProxyOwner);
        proxyInterfaceInfra.upgradeToAndCall(address(orch), data);
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
        vm.makePersistent(address(automation));

        //====== Update the MINTER on the LP Token
        vm.prank(Tester);
        lp.grantRole(keccak256("MINTER_ROLE"), address(wMaster));

        //====== Wrap the proxy as the implementation
        op = Orchestrator(address(proxy));

        //====== Set the DEXes routers
        vm.prank(Tester);
        op.setDexRouterAddress(address(mockBase), 1);
        }

        vm.prank(linkOwnerBase);
        LinkToken(linkBase).grantMintRole(Tester);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(op), 10*10**18);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(wMaster), 10*10**18);
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(User), 10*10**18);

        vm.prank(0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC);
        ERC20Mock(ccipBnM).mint(address(LP), 1000 * 10**18);
        vm.prank(0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC);
        ERC20Mock(ccipBnM).mint(address(User), 100 * 10**18);

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
            0, //uint _chainIndex,
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
        vm.prank(Tester);
        opDst.setDexRouterAddress(address(mockArb), 1);
        }
    }

    modifier setters(){
        //================ SWITCH CHAINS ====================\\
        //BASE
        vm.selectFork(baseTestFork);

        ///======= Pools Allowance
        vm.startPrank(Tester);
        wMaster.setPoolsToSend(arbChainSelector, address(childProxy));
        assertEq(wMaster.s_poolToSendTo(arbChainSelector), address(wChild));

        wMaster.setConceroContractSender(arbChainSelector, address(wChild), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(wChild)), 1);

        wMaster.setConceroContractSender(arbChainSelector, address(proxyDst), 1);
        assertEq(wMaster.s_contractsToReceiveFrom(arbChainSelector, address(proxyDst)), 1);
        vm.stopPrank();

        ///======= Infra Allowance
        vm.startPrank(Tester);
        op.setDstConceroPool(arbChainSelector, address(childProxy));
        assertEq(op.s_poolReceiver(arbChainSelector), address(wChild));

        op.setConceroContract(arbChainSelector, address(proxyDst));

        vm.stopPrank();

        vm.startPrank(address(subOwnerBase));
        functionsRouterBase.addConsumer(16, address(op));
        functionsRouterBase.addConsumer(16, address(wMaster));
        functionsRouterBase.addConsumer(16, address(automation));
        vm.stopPrank();

        vm.prank(0xFaEc9cDC3Ef75713b48f46057B98BA04885e3391);
        tUSDC.transfer(address(mockBase), 1000*10**6);

        //================ SWITCH CHAINS ====================\\
        //ARBITRUM
        vm.selectFork(arbitrumTestFork);

        ///======= Pools Allowance
        vm.startPrank(Tester);
        wChild.setConceroContractSender(baseChainSelector, address(wMaster), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(wMaster)), 1);

        wChild.setConceroContractSender(baseChainSelector, address(op), 1);
        assertEq(wChild.s_contractsToReceiveFrom(baseChainSelector, address(op)), 1);
        vm.stopPrank();

        ///======= Infra Allowance
        vm.startPrank(Tester);
        opDst.setDstConceroPool(baseChainSelector, address(wChild));
        assertEq(opDst.s_poolReceiver(baseChainSelector), address(wChild));

        opDst.setConceroContract(baseChainSelector, address(op));
        vm.stopPrank();

        vm.startPrank(address(subOwnerArb));
        functionsRouterArb.addConsumer(53, address(opDst));
        vm.stopPrank();

        vm.prank(0x4281eCF07378Ee595C564a59048801330f3084eE);
        IERC20(linkArb).transfer(address(opDst), 1*10**18);

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

    ////////////////
    /// REVERTS ////
    ////////////////

    error InsufficientFundsForFees(uint256, uint256);
    error Orchestrator_UnableToCompleteDelegateCall(bytes);
    error Orchestrator_InvalidSwapData();
    function test_swapAndBridgeRevertBecauseBridgeAmount() public setters{
        helper();
        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
        uint amountIn = 29510000000000;
        uint amountOutMin = 9*10**4;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(tUSDC);
        address to = address(op);
        uint deadline = block.timestamp + 1800;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(tUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(mockBase, path, to, deadline)
        });

        /////////////////////////// BRIDGE DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: amountOutMin,
            dstChainSelector: arbChainSelector,
            receiver: User
        });

        // ==== Approve Transfer

        vm.startPrank(User);
        wEth.approve(address(op), amountIn);
        bytes memory InsufficientFunds = abi.encodeWithSelector(InsufficientFundsForFees.selector, amountOutMin , 161996932573903608);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, InsufficientFunds));
        op.swapAndBridge(bridgeData, swapData, swapData);
        vm.stopPrank();

        IDexSwap.SwapData[] memory swapEmptyData = new IDexSwap.SwapData[](0);

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swapAndBridge(bridgeData, swapEmptyData, swapData);
        vm.stopPrank();
    }

    error Orchestrator_InvalidAmount();
    function test_erc20TokenSufficiencyModifier() public setters{
        vm.selectFork(baseTestFork);

        //====== Mock the payload
        IStorage.BridgeData memory data = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: USDC_INITIAL_BALANCE + 1,
            dstChainSelector: arbChainSelector,
            receiver: User
        });

        IDexSwap.SwapData[] memory swap = new IDexSwap.SwapData[](0);

        vm.startPrank(User);
        tUSDC.approve(address(op), USDC_INITIAL_BALANCE + 1);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.bridge(data, swap);
        vm.stopPrank();
        
        uint amountIn = 29510000000000;
        uint amountOutMin = 9*10**4;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(tUSDC);
        address to = address(op);
        uint deadline = block.timestamp + 1800;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(tUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(mockBase, path, to, deadline)
        });


        vm.startPrank(User);
        tUSDC.approve(address(op), USDC_INITIAL_BALANCE + 1);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidAmount.selector));
        op.bridge(data, swapData);
        vm.stopPrank();
    }

    error Orchestrator_InvalidBridgeData();
    function test_BridgeDataModifier() public setters{
        helper();

        vm.prank(0xFaEc9cDC3Ef75713b48f46057B98BA04885e3391);
        tUSDC.transfer(address(User), 1000*10**6);

        //==== Leg 1 - Amount 0 revert

        //====== Mock the payload
        IStorage.BridgeData memory data = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 0,
            dstChainSelector: arbChainSelector,
            receiver: User
        });

        IDexSwap.SwapData[] memory swap = new IDexSwap.SwapData[](0);

        vm.startPrank(User);
        tUSDC.approve(address(op), 1*10**6);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidBridgeData.selector));
        op.bridge(data, swap);
        vm.stopPrank();

        //==== Leg 2 - No ChainSelector

        //====== Mock the payload
        IStorage.BridgeData memory dataTwo = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 20*10**6,
            dstChainSelector: 0,
            receiver: User
        });

        vm.startPrank(User);
        tUSDC.approve(address(op), 20*10**6);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidBridgeData.selector));
        op.bridge(dataTwo, swap);
        vm.stopPrank();

        //===== Leg 3 - Empty receiver
        

        //====== Mock the payload
        IStorage.BridgeData memory dataThree = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 20*10**6,
            dstChainSelector: arbChainSelector,
            receiver: address(0)
        });

        vm.startPrank(User);
        tUSDC.approve(address(op), 20*10**6);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidBridgeData.selector));
        op.bridge(dataThree, swap);
        vm.stopPrank();
    }

    error Orchestrator_InvalidSwapEtherData();
    function test_swapDataModifier() public setters{
        helper();

        uint256 amountIn = 1*10**17;

        uint256 amountOut = 350*10*6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(tUSDC);
        address to = address(User);
        uint deadline = block.timestamp + 1800;

        vm.deal(User, INITIAL_BALANCE);
        assertEq(User.balance, INITIAL_BALANCE);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(tUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(mockBase, path, deadline)
        });

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapEtherData.selector));
        op.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        //===== Leg 2 - Revert In divergent amount

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: 1 *10 **18,
            toToken: address(tUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(mockBase, path, deadline)
        });

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidAmount.selector));
        op.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        //===== Leg 3 - Empty Swap data
        IDexSwap.SwapData[] memory swapDataEmpty = new IDexSwap.SwapData[](0);

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        op.swap{value: amountIn}(swapDataEmpty, User);
        vm.stopPrank();
    }

    error Storage_CallableOnlyByOwner(address, address);
    event Orchestrator_FeeWithdrawal(address, uint256);

    error Orchestrator_OnlyRouterCanFulfill();
    error UnexpectedRequestID(bytes32);
    error ConceroFunctions_ItsNotOrchestrator(address);
    function test_oracleFulfillment() public {
        bytes32 requestId = 0x47e4710d8d5d8e8598e8ab4ab6639c6aa7124620476f299e5abab3634a24036a;

        vm.prank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_OnlyRouterCanFulfill.selector));
        op.handleOracleFulfillment(requestId, "", "");

        vm.prank(address(functionsRouterBase));
        bytes memory unexpectedRequest = abi.encodeWithSelector(UnexpectedRequestID.selector, requestId);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, unexpectedRequest));
        op.handleOracleFulfillment(requestId, "", "");

        //==== Mock a direct call
        vm.expectRevert(abi.encodeWithSelector(ConceroFunctions_ItsNotOrchestrator.selector, address(concero)));
        concero.fulfillRequestWrapper(requestId, "", "");
    }
}
