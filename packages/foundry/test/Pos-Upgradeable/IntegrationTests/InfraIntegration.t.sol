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

//MAster & Infra Scripts
import {DexSwapDeploy} from "../../../script/DexSwapDeploy.s.sol";
import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {ConceroDeploy} from "../../../script/ConceroDeploy.s.sol";
import {OrchestratorDeploy} from "../../../script/OrchestratorDeploy.s.sol";
import {InfraProxyDeploy} from "../../../script/InfraProxyDeploy.s.sol";
import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";
import {AutomationDeploy} from "../../../script/AutomationDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";

//Mock Scripts
import {DexMockDeploy} from "../../../script/DexMockDeploy.s.sol";

//===== Child Scripts
import {ChildPoolDeploy} from "../../../script/ChildPoolDeploy.s.sol";
import {ChildPoolProxyDeploy} from "../../../script/ChildPoolProxyDeploy.s.sol";

//Mocks
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {USDC} from "../../Mocks/USDC.sol";
import {DEXMock} from "../../Mocks/DEXMock.sol";

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
import {CCIPLocalSimulator, WETH9, IRouterClient, BurnMintERC677Helper, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";

contract InfraIntegration is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

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

    //==== Instantiate Deploy Script Arbitrum
    InfraProxyDeploy proxyDeployArbitrum;
    ChildPoolProxyDeploy childProxyDeploy;

    DexSwapDeploy dexDeployArbitrum;
    ChildPoolDeploy childDeployArbitrum;
    ConceroDeploy conceroDeployArbitrum;
    OrchestratorDeploy orchDeployArbitrum;

    //==== Wrapped contract
    Orchestrator wInfraSrc;
    Orchestrator wInfraDst;
    ParentPool wMaster;
    ConceroChildPool wChild;


    //==== Create the instance to mocks
    USDC public mUSDC;
    ERC20Mock public wEth;
    DexMockDeploy public dexMockDeploy;
    DEXMock public dexMock;

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
    IRouter aerodromeRouterArb;

    //Base Testnet variables
    address linkBase = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    address ccipRouterBase = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;
    FunctionsRouter functionsRouterBase = FunctionsRouter(0xf9B8fc078197181C841c296C876945aaa425B278);
    bytes32 donIdBase = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;
    address linkOwnerBase = 0xd5CCdabF11E3De8d2F64022e232aC18001B8acAC;

    //Arb Testnet variables
    address linkArb = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;
    address ccipRouterArb = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;
    address functionsRouterArb = 0x234a5fb5Bd614a7AA2FfAB244D603abFA0Ac5C5C;
    bytes32 donIdArb = 0x66756e2d617262697472756d2d7365706f6c69612d3100000000000000000000;
    address linkOwnerArb = 0xDc03ca2762efcFCE1d7f249d87Db61fbFCd2684B;

    //Local variables
    uint64 localChainSelector;
    address link;
    address ccipRouterLocalSrc;
    address ccipRouterLocalDst;

    address ProxyOwner = makeAddr("ProxyOwner");
    address Tester = makeAddr("Tester");
    address User = makeAddr("User");
    address CrossChainReceiver = makeAddr("CrossChainReceiver");
    address Messenger = makeAddr("Messenger");
    address LP = makeAddr("LiquidityProvider");
    address LiquidityProviderWhale = makeAddr("LiquidityProviderWhale");
    address DummyAddress = makeAddr("DummyAddress");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant LINK_BALANCE = 1 ether;
    uint256 constant USDC_INITIAL_BALANCE = 100 * 10**6;
    uint256 constant USDC_WHALE_BALANCE = 1000 * 10**6;
    uint256 constant LP_INITIAL_BALANCE = 2 ether;
    ERC721 SAFE_LOCK;

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            WETH9 wrappedNative,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        localChainSelector = chainSelector;
        link = address(linkToken);
        ccipRouterLocalSrc = address(sourceRouter);
        ccipRouterLocalDst = address(destinationRouter);

        mUSDC = new USDC("USDC", "USDC", User, USDC_INITIAL_BALANCE);
        wEth = new ERC20Mock();

        ccipLocalSimulator.supportNewToken(address(mUSDC));

        dexDeployBase = new DexSwapDeploy();
        poolDeployBase = new ParentPoolDeploy();
        conceroDeployBase = new ConceroDeploy();
        orchDeployBase = new OrchestratorDeploy();
        proxyDeployBase = new InfraProxyDeploy();
        lpDeployBase = new LPTokenDeploy();
        autoDeployBase = new AutomationDeploy();
        masterProxyDeploy = new ParentPoolProxyDeploy();
        dexMockDeploy = new DexMockDeploy();

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
            15, //_subscriptionId
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
                subscriptionId: 15, //uint64 _subscriptionId,
                donId: donIdBase,
                functionsRouter: address(functionsRouterBase)
            }),
            localChainSelector,
            1, //uint _chainIndex,
            link,
            ccipRouterLocalSrc,
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
            link,
            donIdBase,
            15,
            address(functionsRouterBase),
            ccipRouterLocalSrc,
            address(mUSDC),
            address(lp),
            address(automation),
            address(orch),
            Tester
        );
        }

        dexMock = dexMockDeploy.run();

        //===== Base Proxies
        //====== Update the proxy for the correct address
        vm.prank(ProxyOwner);
        proxyInterfaceInfra.upgradeToAndCall(address(orch), "");
        vm.prank(ProxyOwner);
        proxyInterfaceMaster.upgradeToAndCall(address(pool), "");

        wMaster = ParentPool(payable(address(masterProxy)));

        //====== Update the MINTER on the LP Token
        vm.prank(Tester);
        lp.grantRole(keccak256("MINTER_ROLE"), address(wMaster));

        //====== Wrap the proxy as the implementation
        wInfraSrc = Orchestrator(address(proxy));

        /////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
        //================ SWITCH CHAINS ====================\\
        ///////////////////////////////////////////////////////
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
            address(wrappedNative)
        );

        conceroDst = conceroDeployArbitrum.run(
            IStorage.FunctionsVariables ({
                subscriptionId: 0, //uint64 _subscriptionId,
                donId: donIdArb,
                functionsRouter: functionsRouterArb
            }),
            localChainSelector,
            1, //uint _chainIndex,
            link,
            ccipRouterLocalDst,
            address(dexDst),
            address(childProxy),
            address(proxyDst)
        );

        orchDst = orchDeployArbitrum.run(
            functionsRouterArb,
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
            link,
            ccipRouterLocalDst,
            localChainSelector,
            address(mUSDC),
            Tester
        );

        wChild = ConceroChildPool(payable(address(childProxy)));
        
        //====== Update the proxy for the correct address
        vm.prank(ProxyOwner);
        proxyInterfaceInfraArb.upgradeToAndCall(address(orchDst), "");
        vm.prank(ProxyOwner);
        proxyInterfaceChild.upgradeToAndCall(address(child), "");

        //====== Wrap the proxy as the implementation
        wInfraDst = Orchestrator(address(proxyDst));
        }
    }

    function setters() public {
        vm.startPrank(defaultSender);
        //Infra Src
        wInfraSrc.setClfPremiumFees(localChainSelector, 4000000000000000);
        wInfraSrc.setLastGasPrices(localChainSelector, 5767529);
        wInfraSrc.setLatestLinkUsdcRate(13_560_000_000_000_000_000);
        wInfraSrc.setLatestNativeUsdcRate(3_383_730_000_000_000_000_000);
        wInfraSrc.setLatestLinkNativeRate(40091515);


        wInfraSrc.setConceroContract(localChainSelector, address(proxyDst));
        wInfraSrc.setDstConceroPool(localChainSelector, address(wChild));

        //Infra Dest
        wInfraDst.setClfPremiumFees(localChainSelector, 4000000000000000);

        wInfraDst.setConceroContract(localChainSelector, address(proxy));
        wInfraDst.setDstConceroPool(localChainSelector, address(wMaster));

        wInfraSrc.setDexRouterAddress(address(dexMock), 1);

        vm.stopPrank();

        vm.startPrank(Tester);

        //Parent Pool
        masterProxy.setConceroContractSender(localChainSelector, address(wChild), 1);
        masterProxy.setPoolsToSend(localChainSelector, address(wChild));

        //Child Pool
        childProxy.setConceroContractSender(localChainSelector, address(wMaster), 1);
        childProxy.setConceroContractSender(localChainSelector, address(wInfraSrc), 1);
        vm.stopPrank();

        mUSDC.mint(LiquidityProviderWhale, USDC_WHALE_BALANCE);
        mUSDC.mint(address(dexMock), USDC_WHALE_BALANCE);
        wEth.mint(User, 10 * 10**18);
    }

    //To run the test below you need to comment out the line 79 of Concero.sol. Functions doesn't work in this environment.
    function test_bridgeWithoutFunctions() public {
        setters();

        vm.startPrank(LiquidityProviderWhale);
        mUSDC.approve(address(wMaster), USDC_WHALE_BALANCE);
        wMaster.depositLiquidity(USDC_WHALE_BALANCE); //1000
        vm.stopPrank();

        //====== Mock the payload
        IStorage.BridgeData memory data = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 10 *10**6,
            dstChainSelector: localChainSelector,
            receiver: CrossChainReceiver
        });

        IDexSwap.SwapData[] memory swap = new IDexSwap.SwapData[](0);

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);

        vm.startPrank(User);
        mUSDC.approve(address(wInfraSrc), 10 *10**6);
        wInfraSrc.bridge(data, swap);
        vm.stopPrank();

        //Final amount is = Transferred value - (src fee + dst fee)
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 9852385); //Here, we don't have CCIP costs because testing locally, the fee is 0.
    }

    error Concero_ItsNotOrchestrator(address);
    function test_swapAndBridgeWithoutFunctions() public {
        setters();
        
        vm.deal(User, INITIAL_BALANCE);

        vm.startPrank(LiquidityProviderWhale);
        mUSDC.approve(address(wMaster), USDC_WHALE_BALANCE);
        wMaster.depositLiquidity(USDC_WHALE_BALANCE); //1000
        vm.stopPrank();

        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = address(wInfraSrc);
        uint deadline = block.timestamp + 1800;

        vm.startPrank(User);
        wEth.approve(address(concero), amountIn);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(dexMock, path, to, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(wInfraSrc), 0.1 ether);

        /////////////////////////// BRIDGE DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 350 *10**6,
            dstChainSelector: localChainSelector,
            receiver: CrossChainReceiver
        });

        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        IDexSwap.SwapData[] memory swapDataDst = new IDexSwap.SwapData[](0);

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);
        assertEq(mUSDC.balanceOf(address(dexMock)), USDC_WHALE_BALANCE);

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Concero_ItsNotOrchestrator.selector, address(concero)));
        concero.startBridge(bridgeData, swapData);

        wInfraSrc.swapAndBridge(bridgeData, swapData, swapDataDst);
        vm.stopPrank();

        assertTrue(mUSDC.balanceOf(CrossChainReceiver) > 340 *10**6);

        /////////////////////////// MOCK WITHDRAW \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        vm.expectRevert(abi.encodeWithSelector(Storage_CallableOnlyByOwner.selector, address(this), defaultSender));
        wInfraSrc.withdrawERC20Fee(address(mUSDC));

        vm.prank(defaultSender);
        vm.expectEmit();
        emit Orchestrator_FeeWithdrawal(defaultSender, 137753); //Fee 137753
        wInfraSrc.withdrawERC20Fee(address(mUSDC));
    }

    ////////////////
    /// REVERTS ////
    ////////////////
    error InsufficientFundsForFees(uint256, uint256);
    error Orchestrator_UnableToCompleteDelegateCall(bytes);
    function test_swapAndBridgeRevertBecauseBridgeAmount() public {
        
        setters();
        
        vm.deal(User, INITIAL_BALANCE);

        vm.startPrank(LiquidityProviderWhale);
        mUSDC.approve(address(wMaster), USDC_WHALE_BALANCE);
        wMaster.depositLiquidity(USDC_WHALE_BALANCE); //1000
        vm.stopPrank();

        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        
        uint amountIn = 29510000000000;
        uint amountOutMin = 9*10**4;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = address(wInfraSrc);
        uint deadline = block.timestamp + 1800;

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
                            dexType: IDexSwap.DexType.UniswapV2,
                            fromToken: address(wEth),
                            fromAmount: amountIn,
                            toToken: address(mUSDC),
                            toAmount: amountOutMin,
                            toAmountMin: amountOutMin,
                            dexData: abi.encode(dexMock, path, to, deadline)
        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(wInfraSrc), amountIn);

        /////////////////////////// BRIDGE DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        IStorage.BridgeData memory bridgeData = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: amountOutMin,
            dstChainSelector: localChainSelector,
            receiver: CrossChainReceiver
        });

        /////////////////////////// SWAP DATA MOCKED \\\\\\\\\\\\\\\\\\\\\\\\\\\\
        IDexSwap.SwapData[] memory swapDataDst = new IDexSwap.SwapData[](0);

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);
        assertEq(mUSDC.balanceOf(address(dexMock)), USDC_WHALE_BALANCE);

        vm.startPrank(User);
        bytes memory InsufficientFundsForFees = abi.encodeWithSelector(InsufficientFundsForFees.selector, amountOutMin , 137753641354758127);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, InsufficientFundsForFees));
        wInfraSrc.swapAndBridge(bridgeData, swapData, swapDataDst);
        vm.stopPrank();

        IDexSwap.SwapData[] memory swapEmptyData = new IDexSwap.SwapData[](0);

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        wInfraSrc.swapAndBridge(bridgeData, swapEmptyData, swapDataDst);
        vm.stopPrank();
    }

    error Orchestrator_InvalidAmount();
    function test_erc20TokenSufficiencyModifier() public {        
        setters();

        vm.startPrank(LiquidityProviderWhale);
        mUSDC.approve(address(wMaster), USDC_WHALE_BALANCE);
        wMaster.depositLiquidity(USDC_WHALE_BALANCE); //1000
        vm.stopPrank();

        //====== Mock the payload
        IStorage.BridgeData memory data = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: USDC_INITIAL_BALANCE + 1,
            dstChainSelector: localChainSelector,
            receiver: CrossChainReceiver
        });

        IDexSwap.SwapData[] memory swap = new IDexSwap.SwapData[](0);

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);

        vm.startPrank(User);
        mUSDC.approve(address(wInfraSrc), USDC_INITIAL_BALANCE + 1);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidAmount.selector));
        wInfraSrc.bridge(data, swap);
        vm.stopPrank();
    }

    error Orchestrator_InvalidBridgeData();
    function test_BridgeDataModifier() public {
        setters();

        vm.startPrank(LiquidityProviderWhale);
        mUSDC.approve(address(wMaster), USDC_WHALE_BALANCE);
        wMaster.depositLiquidity(USDC_WHALE_BALANCE); //1000
        vm.stopPrank();

        //==== Leg 1 - Amount 0 revert

        //====== Mock the payload
        IStorage.BridgeData memory data = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 0,
            dstChainSelector: localChainSelector,
            receiver: CrossChainReceiver
        });

        IDexSwap.SwapData[] memory swap = new IDexSwap.SwapData[](0);

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);

        vm.startPrank(User);
        mUSDC.approve(address(wInfraSrc), 1*10**6);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidBridgeData.selector));
        wInfraSrc.bridge(data, swap);
        vm.stopPrank();

        //==== Leg 2 - No ChainSelector

        //====== Mock the payload
        IStorage.BridgeData memory dataTwo = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 20*10**6,
            dstChainSelector: 0,
            receiver: CrossChainReceiver
        });

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);

        vm.startPrank(User);
        mUSDC.approve(address(wInfraSrc), 20*10**6);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidBridgeData.selector));
        wInfraSrc.bridge(dataTwo, swap);
        vm.stopPrank();

        //===== Leg 3 - Empty receiver
        

        //====== Mock the payload
        IStorage.BridgeData memory dataThree = IStorage.BridgeData({
            tokenType: IStorage.CCIPToken.usdc,
            amount: 20*10**6,
            dstChainSelector: localChainSelector,
            receiver: address(0)
        });

        //====== Check Receiver balance
        assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);

        vm.startPrank(User);
        mUSDC.approve(address(wInfraSrc), 20*10**6);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidBridgeData.selector));
        wInfraSrc.bridge(dataThree, swap);
        vm.stopPrank();
    }

    error Orchestrator_InvalidSwapData();
    error Orchestrator_InvalidSwapEtherData();
    function test_swapDataModifier() public {
        setters();

        uint256 amountIn = 1*10**17;

        uint256 amountOut = 350*10*6;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = address(User);
        uint deadline = block.timestamp + 1800;

        vm.deal(User, INITIAL_BALANCE);
        assertEq(User.balance, INITIAL_BALANCE);

        IDexSwap.SwapData[] memory swapData = new IDexSwap.SwapData[](1);
        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(wEth),
            fromAmount: amountIn,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV2, path, deadline)
        });

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapEtherData.selector));
        wInfraSrc.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        //===== Leg 2 - Revert In divergent amount

        swapData[0] = IDexSwap.SwapData({
            dexType: IDexSwap.DexType.UniswapV2Ether,
            fromToken: address(0),
            fromAmount: 1 *10 **18,
            toToken: address(mUSDC),
            toAmount: amountOut,
            toAmountMin: amountOut,
            dexData: abi.encode(uniswapV2, path, deadline)
        });

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidAmount.selector));
        wInfraSrc.swap{value: amountIn}(swapData, User);
        vm.stopPrank();

        //===== Leg 3 - Empty Swap data
        IDexSwap.SwapData[] memory swapDataEmpty = new IDexSwap.SwapData[](0);

        vm.startPrank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_InvalidSwapData.selector));
        wInfraSrc.swap{value: amountIn}(swapDataEmpty, User);
        vm.stopPrank();
    }

    error Storage_CallableOnlyByOwner(address, address);
    event Orchestrator_FeeWithdrawal(address, uint256);
    function test_withdrawEtherFee() public {
        vm.deal(address(wInfraSrc), 1*10**18);

        vm.prank(User);
        vm.expectRevert(abi.encodeWithSelector(Storage_CallableOnlyByOwner.selector, User, defaultSender));
        wInfraSrc.withdrawEtherFee();

        uint256 previousBalance = defaultSender.balance;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit Orchestrator_FeeWithdrawal(defaultSender, 1*10**18);
        wInfraSrc.withdrawEtherFee();

        assertEq(defaultSender.balance, previousBalance + 1*10**18);
    }

    error Orchestrator_OnlyRouterCanFulfill();
    error UnexpectedRequestID(bytes32);
    error ConceroFunctions_ItsNotOrchestrator(address);
    function test_oracleFulfillment() public {
        bytes32 requestId = 0x47e4710d8d5d8e8598e8ab4ab6639c6aa7124620476f299e5abab3634a24036a;

        vm.prank(User);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_OnlyRouterCanFulfill.selector));
        wInfraSrc.handleOracleFulfillment(requestId, "", "");

        vm.prank(address(functionsRouterBase));
        bytes memory unexpectedRequest = abi.encodeWithSelector(UnexpectedRequestID.selector, requestId);
        vm.expectRevert(abi.encodeWithSelector(Orchestrator_UnableToCompleteDelegateCall.selector, unexpectedRequest));
        wInfraSrc.handleOracleFulfillment(requestId, "", "");

        //==== Mock a direct call
        vm.expectRevert(abi.encodeWithSelector(ConceroFunctions_ItsNotOrchestrator.selector, address(concero)));
        concero.fulfillRequestWrapper(requestId, "", "");
    }

    ////////////////
    /// GETTERS ////
    ////////////////
}