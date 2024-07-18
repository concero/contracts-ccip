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
import {IConcero, IDexSwap} from "contracts/Interfaces/IConcero.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";

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
        vm.makePersistent(address(automation));

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
        vm.prank(Tester);
        LinkToken(linkBase).mint(address(User), 10*10**18);

        vm.prank(0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC);
        ERC20Mock(ccipBnM).mint(address(LP), 1000 * 10**6);
        vm.prank(0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC);
        ERC20Mock(ccipBnM).mint(address(User), 100 * 10**6);
        vm.prank(0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC);
        ERC20Mock(ccipBnM).mint(address(mockBase), 1000 * 10**6);

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
        vm.prank(defaultSender);
        opDst.setDexRouterAddress(address(mockArb), 1);
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// HELPERS MODULE ///////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
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
        vm.startPrank(defaultSender);
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
        vm.startPrank(defaultSender);
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

    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// MODIFIERS ///////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////

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

        //It will not revert because fees are 0 on the first call.
        // vm.startPrank(User);
        // wEth.approve(address(op), amountIn);
        // bytes memory InsufficientFunds = abi.encodeWithSelector(InsufficientFundsForFees.selector, amountOutMin , 161996932573903608);
        // vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, InsufficientFunds));
        // op.swapAndBridge(bridgeData, swapData, swapData);
        // vm.stopPrank();

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
    function test_oracleFulfillmentRevert() public {
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

    //////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POOL MODULE ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////

    error ParentPool_AmountBelowMinimum(uint256);
    error ParentPool_MaxCapReached(uint256);
    error ParentPool_AmountNotAvailableYet(uint256);
    error ParentPool_InsufficientBalance();
    error ParentPool_ActiveRequestNotFulfilledYet();
    error ParentPool_CallerIsNotTheProxy(address);
    event ParentPool_MasterPoolCapUpdated(uint256 _newCap);
    event ParentPool_SuccessfulDeposited(address, uint256 , address);
    event ParentPool_MessageSent(bytes32, uint64, address, address, uint256);
    event ParentPool_WithdrawRequest(address,address,uint256);
    event ParentPool_Withdrawn(address,address,uint256);
    // function test_LiquidityProvidersDepositAndOpenARequest() public setters {
    //     vm.selectFork(baseTestFork);

    //     uint256 lpBalance = IERC20(ccipBnM).balanceOf(LP);
    //     uint256 depositLowAmount = 10*10**6;

    //     //======= LP Deposits Low Amount of USDC on the Main Pool to revert on Min Amount
    //     vm.startPrank(LP);
    //     IERC20(ccipBnM).approve(address(wMaster), depositLowAmount);
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
    //     IERC20(ccipBnM).approve(address(wMaster), depositEnoughAmount);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_MaxCapReached.selector, 50*10**6));
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     vm.stopPrank();

    //     //======= Increase the CAP
    //     vm.expectEmit();
    //     vm.prank(Tester);
    //     emit ParentPool_MasterPoolCapUpdated(1000*10**6);
    //     wMaster.setPoolCap(1000*10**6);

    //     vm.startPrank(LP);
    //     IERC20(ccipBnM).approve(address(wMaster), depositEnoughAmount);
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);
    //     vm.stopPrank();

    //     //======= Switch to Base
    //     vm.selectFork(baseTestFork);

    //     //======= Check LP balance
    //     assertEq(IERC20(ccipBnM).balanceOf(LP), lpBalance - depositEnoughAmount);

    //     //======= We check the pool balance;
    //                 //Here, the LP Fees will be compounding directly for the LP address
    //     uint256 poolBalance = IERC20(ccipBnM).balanceOf(address(wMaster));
    //     assertEq(poolBalance, depositEnoughAmount/2);

    //     uint256 lpTokenUserBalance = lp.balanceOf(LP);
    //     // assertEq(lpTokenUserBalance, (depositEnoughAmount * 10**18) / 10**6);

    //     //======= Revert on amount bigger than balance
    //     vm.startPrank(LP);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_InsufficientBalance.selector));
    //     wMaster.startWithdrawal(lpTokenUserBalance + 10);
    //     vm.stopPrank();

    //     //======= Request Withdraw without any accrued fee
    //     vm.startPrank(LP);
    //     vm.expectEmit();
    //     emit ParentPool_WithdrawRequest(LP, ccipBnM, block.timestamp + 597_600);
    //     wMaster.startWithdrawal(lpTokenUserBalance);
    //     vm.stopPrank();

    //     //======= Revert on amount bigger than balance
    //     vm.startPrank(LP);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_ActiveRequestNotFulfilledYet.selector));
    //     wMaster.startWithdrawal(lpTokenUserBalance);
    //     vm.stopPrank();

    //     //======= No operations are made. Advance time
    //     vm.warp(7 days);

    //     //======= Revert Because money not arrived yet
    //     vm.startPrank(LP);
    //     lp.approve(address(wMaster), lpTokenUserBalance);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_AmountNotAvailableYet.selector, 50*10**6));
    //     wMaster.completeWithdrawal();
    //     vm.stopPrank();

    //     //======= Switch to Arbitrum
    //     vm.selectFork(arbitrumTestFork);

    //     //======= Calls ChildPool to send the money
    //     vm.prank(Messenger);
    //     wChild.ccipSendToPool(LP, depositEnoughAmount/2);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(baseTestFork);

    //     //======= Revert because balance was used.
    //     vm.prank(address(wMaster));
    //     IERC20(ccipBnM).transfer(User, 10*10**6);

    //     vm.startPrank(LP);
    //     lp.approve(address(wMaster), lpTokenUserBalance);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_InsufficientBalance.selector));
    //     wMaster.completeWithdrawal();
    //     vm.stopPrank();

    //     vm.prank(address(User));
    //     IERC20(ccipBnM).transfer(address(wMaster), 10*10**6);

    //     vm.startPrank(LP);
    //     lp.approve(address(wMaster), lpTokenUserBalance);
    //     vm.expectRevert(abi.encodeWithSelector(ParentPool_CallerIsNotTheProxy.selector, address(pool)));
    //     pool.completeWithdrawal();
    //     vm.stopPrank();

    //     //======= Withdraw after the lock period and cross-chain transference
    //     vm.startPrank(LP);
    //     lp.approve(address(wMaster), lpTokenUserBalance);
    //     wMaster.completeWithdrawal();
    //     vm.stopPrank();

    //     // //======= Check LP balance
    //     assertEq(IERC20(ccipBnM).balanceOf(LP), lpBalance);
    // }

    //Callback isn't performed on forked environment
    // function test_PoolFees() public setters {
    //     vm.selectFork(baseTestFork);
    //     uint256 lpBnMBalance = 1000*10**6;

    //     assertEq(IERC20(ccipBnM).balanceOf(LP), lpBnMBalance);

    //     assertEq(IERC20(ccipBnM).balanceOf(address(wMaster)),0);
    //     assertEq(lp.balanceOf(address(LP)), 0);

    //     vm.prank(LP);
    //     IERC20(ccipBnM).approve(address(wMaster), 500*10**6);
    //     vm.prank(LP);
    //     wMaster.depositLiquidity(500*10**6);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);

    //     vm.selectFork(baseTestFork);
    //     assertEq(IERC20(ccipBnM).balanceOf(address(wMaster)), 250*10**6);
    //     assertEq(IERC20(ccipBnM).balanceOf(address(LP)), 500*10**6);
    //     assertTrue(lp.balanceOf(address(LP)) > 400*10**18);

    //     /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
    //     // helper();
        
    //     // uint amountIn = 1*10**17;
    //     // uint amountOutMin = 350*10**6;
    //     // address[] memory path = new address[](2);
    //     // path[0] = address(wEth);
    //     // path[1] = address(ccipBnM);
    //     // address to = address(op);
    //     // uint deadline = block.timestamp + 1800;

    //     // IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     // swapData[0] = IDexSwap.SwapData({
    //     //                     dexType: IDexSwap.DexType.UniswapV2,
    //     //                     fromToken: address(wEth),
    //     //                     fromAmount: amountIn,
    //     //                     toToken: address(tUSDC),
    //     //                     toAmount: amountOutMin,
    //     //                     toAmountMin: amountOutMin,
    //     //                     dexData: abi.encode(mockBase, path, to, deadline)
    //     // });

    //     // /////////////////////////// BRIDGE DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
    //     // IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
    //     //     tokenType: IStorage.CCIPToken.usdc,
    //     //     amount: 300 *10**6,
    //     //     dstChainSelector: arbChainSelector,
    //     //     receiver: User
    //     // });

    //     // /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
    //     // uint amountInDst = 300*10**6;
    //     // uint amountOutMinDst = 1*10**17;
    //     // address[] memory pathDst = new address[](2);
    //     // pathDst[0] = address(ccipBnMArb);
    //     // pathDst[1] = address(arbWEth);
    //     // address toDst = address(User);
    //     // uint deadlineDst = block.timestamp + 1800;

    //     // IDexSwap.SwapData[] memory swapDstData = new IDexSwap.SwapData[](1);
    //     // swapDstData[0] = IDexSwap.SwapData({
    //     //                     dexType: IDexSwap.DexType.UniswapV2,
    //     //                     fromToken: address(wEth),
    //     //                     fromAmount: amountInDst,
    //     //                     toToken: address(tUSDC),
    //     //                     toAmount: amountOutMinDst,
    //     //                     toAmountMin: amountOutMinDst,
    //     //                     dexData: abi.encode(mockArb, pathDst, toDst, deadlineDst)
    //     // });

    //     // // ==== Approve Transfer
    //     // vm.startPrank(User);
    //     // wEth.approve(address(op), 0.1 ether);
    //     // op.swapAndBridge(bridgeData, swapData, swapDstData);
    //     // vm.stopPrank();
    // }

    ////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// BRIDGE MODULE ///////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////
    
    error Concero_ItsNotOrchestrator(address);
    // function test_swapAndBridgeWithoutFunctions() public setters{
    //     helper();

    //     /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
    //     uint amountIn = 1*10**17;
    //     uint amountOutMin = 350*10**6;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(tUSDC);
    //     address to = address(op);
    //     uint deadline = block.timestamp + 1800;

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(tUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(mockBase, path, to, deadline)
    //     });

    //     /////////////////////////// BRIDGE DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
    //     IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
    //         tokenType: IStorage.CCIPToken.usdc,
    //         amount: 350 *10**6,
    //         dstChainSelector: arbChainSelector,
    //         receiver: User
    //     });

    //     // ==== Approve Transfer
    //     vm.startPrank(User);
    //     wEth.approve(address(op), 0.1 ether);
    //     vm.expectRevert(abi.encodeWithSelector(Concero_ItsNotOrchestrator.selector, address(concero)));
    //     concero.startBridge(bridgeData, swapData);

    //     op.swapAndBridge(bridgeData, swapData, swapData);
    //     vm.stopPrank();
    // }

    // function test_userBridge() public setters {
    //     vm.selectFork(baseTestFork);

    //     //======= LP Deposits enough to go through, but revert on max Cap
    //     uint256 depositEnoughAmount = 100*10**6;

    //     //======= Increase the CAP
    //     vm.expectEmit();
    //     vm.prank(Tester);
    //     emit ParentPool_MasterPoolCapUpdated(1000*10**6);
    //     wMaster.setPoolCap(1000*10**6);

    //     vm.startPrank(LP);
    //     IERC20(ccipBnM).approve(address(wMaster), depositEnoughAmount);
    //     wMaster.depositLiquidity(depositEnoughAmount);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);
    //     vm.stopPrank();

    //     //====== Check Receiver balance
    //     assertEq(IERC20(ccipBnMArb).balanceOf(User), 0);
    //     assertEq(IERC20(ccipBnMArb).balanceOf(address(wChild)), depositEnoughAmount / 2);

    //     vm.selectFork(baseTestFork);

    //     //====== Mock the payload
    //     uint256 amountToSend = 10 *10**6;

    //     IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
    //         tokenType: IStorage.CCIPToken.bnm,
    //         amount: amountToSend,
    //         dstChainSelector: arbChainSelector,
    //         receiver: User
    //     });

    //     /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
    //     uint amountIn = 1*10**17;
    //     uint amountOutMin = 350*10**6;
    //     address[] memory path = new address[](2);
    //     path[0] = address(wEth);
    //     path[1] = address(tUSDC);
    //     address to = address(op);
    //     uint deadline = block.timestamp + 1800;

    //     IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
    //     swapData[0] = IDexSwap.SwapData({
    //                         dexType: IDexSwap.DexType.UniswapV2,
    //                         fromToken: address(wEth),
    //                         fromAmount: amountIn,
    //                         toToken: address(tUSDC),
    //                         toAmount: amountOutMin,
    //                         toAmountMin: amountOutMin,
    //                         dexData: abi.encode(mockBase, path, to, deadline)
    //     });

    //     vm.startPrank(User);
    //     IERC20(ccipBnM).approve(address(op), amountToSend);
    //     op.bridge(bridgeData, swapData);
    //     ccipLocalSimulatorFork.switchChainAndRouteMessage(arbitrumTestFork);
    //     vm.stopPrank();

    //     //====== Check Receiver balance
    //     assertEq(IERC20(ccipBnMArb).balanceOf(User), 9990000); //Amount - fee = 9831494
        
    //     // assertTrue(op.s_lastGasPrices(arbChainSelector) > 0);
    //     // assertTrue(op.s_latestLinkUsdcRate() > 0);
    //     // assertTrue(op.s_latestNativeUsdcRate() > 0);
    //     // assertTrue(op.s_latestLinkNativeRate() > 0);
    // }

    ////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////// AUTOMATION MODULE ///////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////

    event ConceroAutomation_ForwarderAddressUpdated(address);
    function test_addForwarder() public {
        address fakeForwarder = address(0x1);

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setForwarderAddress(fakeForwarder);

        //====== Success
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_ForwarderAddressUpdated(fakeForwarder);
        automation.setForwarderAddress(fakeForwarder);
    }

    event ConceroAutomation_DonSecretVersionUpdated(uint64);
    error OwnableUnauthorizedAccount(address);
    function test_setDonHostedSecretsVersion() public {
        uint64 secretVersion = 2;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setDonHostedSecretsVersion(secretVersion);

        //====== Success
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_DonSecretVersionUpdated(secretVersion);
        automation.setDonHostedSecretsVersion(secretVersion);
    }

    event ConceroAutomation_DonHostedSlotId(uint8);
    function test_setDonHostedSecretsSlotId() public {
        uint8 slotId = 3;

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setDonHostedSecretsSlotId(slotId);

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_DonHostedSlotId(slotId);
        automation.setDonHostedSecretsSlotId(slotId);
    }

    event ConceroAutomation_HashSumUpdated(bytes32);
    function test_setSrcJsHashSum() public {
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setJsHashSum(hashSum);

        //====== Success

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_HashSumUpdated(hashSum);
        automation.setJsHashSum(hashSum); 
    }

    event ConceroAutomation_EthersHashSumUpdated(bytes32);
    function test_setEthersHashSum() public {
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        automation.setEthersHashSum(hashSum);

        //====== Success

        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroAutomation_EthersHashSumUpdated(hashSum);
        automation.setEthersHashSum(hashSum);
    }

    event ConceroAutomation_RequestAdded(address);
    error ConceroAutomation_CallerNotAllowed(address);
    function test_pendingWithdrawal() public {
        //===== Ownable Revert
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        automation.addPendingWithdrawal(User);

        vm.prank(address(masterProxy));
        vm.expectEmit();
        emit ConceroAutomation_RequestAdded(User);
        automation.addPendingWithdrawal(User);
    }

    function test_checkUpkeep() public {
        //====== Not Forwarder
        // vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        // automation.checkUpkeep("");

        //====== Successful Call
        //=== Add Forwarder
        address fakeForwarder = address(0x1);
        vm.prank(Tester);
        automation.setForwarderAddress(fakeForwarder);

        //=== Create Request
        vm.prank(address(masterProxy));
        automation.addPendingWithdrawal(User);

        address[] memory recoveredRequest = automation.getPendingRequests();

        assertEq(recoveredRequest[0], User);

        //=== check return
        vm.prank(fakeForwarder);
        (bool positiveResponse, bytes memory performData) = automation.checkUpkeep("");

        assertEq(positiveResponse, true); //Because the request don't exist, but the address is on the array

        (address LiquidityProvider, uint256 amountToRequest) = abi.decode(performData,(address, uint256));

        assertEq(LiquidityProvider, User);
        assertEq(amountToRequest, 0);
    }

    event ConceroAutomation_UpkeepPerformed(bytes32);
    error ConceroAutomation_WithdrawAlreadyTriggered(address liquidityProvider);
    function test_performUpkeep() public setters{
        vm.selectFork(baseTestFork);

        //====== Not Forwarder
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_CallerNotAllowed.selector, address(this)));
        automation.performUpkeep("");

        //====== Successful Call
        //=== Add Forwarder
        address fakeForwarder = address(0x1);
        vm.prank(Tester);
        automation.setForwarderAddress(fakeForwarder);

        //=== Create Request
        vm.prank(address(masterProxy));
        automation.addPendingWithdrawal(User);

        uint256 length = automation.getPendingWithdrawRequestsLength();

        assertEq(length, 1);

        address[] memory recoveredRequest = automation.getPendingRequests();

        assertEq(recoveredRequest[0], User);

        //=== move in time
        vm.warp(block.timestamp + 7 days);

        //=== check return
        vm.prank(fakeForwarder);
        (/*bool positiveResponse*/, bytes memory performData) = automation.checkUpkeep("");

        //=== Simulate Perform Withdraw
        vm.prank(fakeForwarder);
        automation.performUpkeep(performData);

        //=== Try to perform Withdraw again to revert
        vm.prank(fakeForwarder);
        vm.expectRevert(abi.encodeWithSelector(ConceroAutomation_WithdrawAlreadyTriggered.selector, User));
        automation.performUpkeep(performData);
    }
}
