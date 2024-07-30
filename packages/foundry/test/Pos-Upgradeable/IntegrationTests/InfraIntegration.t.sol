// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//Foundry
import {Test, console} from "forge-std/Test.sol";

//Master & Infra Contracts
import {DexSwap} from "contracts/DexSwap.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
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
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter02, IV3SwapRouter} from "contracts/Interfaces/ISwapRouter02.sol";

//Chainlink
import {CCIPLocalSimulator, WETH9, IRouterClient, BurnMintERC677Helper, LinkToken} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRouter} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";

contract InfraIntegration is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    //==== Instantiate Base Contracts
    DexSwap public dex;
    ConceroParentPool public pool;
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
    Orchestrator wInfraSrc;
    Orchestrator wInfraDst;
    ConceroParentPool wMaster;
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
    FunctionsRouter functionsRouterBase =
        FunctionsRouter(0xf9B8fc078197181C841c296C876945aaa425B278);
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
    uint256 constant USDC_INITIAL_BALANCE = 100 * 10 ** 6;
    uint256 constant USDC_WHALE_BALANCE = 1000 * 10 ** 6;
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
                15, //_subscriptionId
                2, //_slotId
                address(functionsRouterBase), //_router,
                address(masterProxy),
                Tester
            );

            // DexSwap Contract
            dex = dexDeployBase.run(address(proxy));

            concero = conceroDeployBase.run(
                IStorage.FunctionsVariables({
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
                Tester,
                [Messenger, address(0), address(0)]
            );
        }

        dexMock = dexMockDeploy.run();

        //===== Base Proxies
        //====== Update the proxy for the correct address
        uint256 lastGasPrice = 5767529;
        uint256 latestLinkUsdcRate = 13_560_000_000_000_000_000;
        uint256 latestNativeUsdcRate = 3_383_730_000_000_000_000_000;
        uint256 latestLinkNativeRate = 40091515;
        bytes memory data = abi.encodeWithSignature(
            "initialize(uint64,uint256,uint256,uint256,uint256)",
            localChainSelector,
            lastGasPrice,
            latestLinkUsdcRate,
            latestNativeUsdcRate,
            latestLinkNativeRate
        );
        vm.prank(ProxyOwner);
        proxyInterfaceInfra.upgradeToAndCall(address(orch), data);
        vm.prank(ProxyOwner);
        proxyInterfaceMaster.upgradeToAndCall(address(pool), "");

        wMaster = ConceroParentPool(payable(address(masterProxy)));

        //====== Update the MINTER on the LP Token
        vm.prank(Tester);
        lp.grantRole(keccak256("MINTER_ROLE"), address(wMaster));

        //====== Wrap the proxy as the implementation
        wInfraSrc = Orchestrator(payable(proxy));

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
            childProxy = childProxyDeploy.run(address(orchEmptyDst), ProxyOwner, "");

            //====== Deploy the proxy with the dummy Orch
            proxyDst = proxyDeployArbitrum.run(address(orchEmptyDst), ProxyOwner, "");

            proxyInterfaceInfraArb = ITransparentUpgradeableProxy(address(proxyDst));
            proxyInterfaceChild = ITransparentUpgradeableProxy(address(childProxy));

            dexDst = dexDeployArbitrum.run(address(proxyDst));

            conceroDst = conceroDeployArbitrum.run(
                IStorage.FunctionsVariables({
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
                address(childProxy),
                link,
                ccipRouterLocalDst,
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
            wInfraDst = Orchestrator(payable(proxyDst));
        }
    }

    function setters() public {
        vm.startPrank(defaultSender);
        //Infra Src
        wInfraSrc.setClfPremiumFees(localChainSelector, 4000000000000000);

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
        wMaster.setConceroContractSender(localChainSelector, address(wChild), 1);
        wMaster.setPools(localChainSelector, address(wChild), false);

        //Child Pool
        wChild.setConceroContractSender(localChainSelector, address(wMaster), 1);
        wChild.setConceroContractSender(localChainSelector, address(wInfraSrc), 1);
        vm.stopPrank();

        mUSDC.mint(LiquidityProviderWhale, USDC_WHALE_BALANCE);
        mUSDC.mint(address(dexMock), USDC_WHALE_BALANCE);
        wEth.mint(User, 10 * 10 ** 18);
    }

    /// IN ORDER TO RUN THESE TESTS, THE USDC ON `getUSDCAddressByChainIndex` FUNCTION NEED TO BE UPDATED TO THE LOCAL VERSION
    // ADDRESS: 0x2e234DAe75C793f67A35089C9d99245E1C58470b
    // And comment out the line 79 of Concero.sol. Functions doesn't work in this environment.
    // function test_bridgeWithoutFunctions() public {
    //     setters();

    //     vm.startPrank(LiquidityProviderWhale);
    //     mUSDC.approve(address(wMaster), USDC_WHALE_BALANCE);
    //     wMaster.depositLiquidity(USDC_WHALE_BALANCE); //1000
    //     vm.stopPrank();

    //     //====== Mock the payload
    //     IStorage.BridgeData memory data = IStorage.BridgeData({
    //         tokenType: IStorage.CCIPToken.usdc,
    //         amount: 10 *10**6,
    //         dstChainSelector: localChainSelector,
    //         receiver: CrossChainReceiver
    //     });

    //     IDexSwap.SwapData[] memory swap = new IDexSwap.SwapData[](0);

    //     //====== Check Receiver balance
    //     assertEq(mUSDC.balanceOf(CrossChainReceiver), 0);

    //     vm.startPrank(User);
    //     mUSDC.approve(address(wInfraSrc), 10 *10**6);
    //     wInfraSrc.bridge(data, swap);
    //     vm.stopPrank();

    //     //Final amount is = Transferred value - (src fee + dst fee)
    //     assertEq(mUSDC.balanceOf(CrossChainReceiver), 9852385); //Here, we don't have CCIP costs because testing locally, the fee is 0.
    // }

    ////////////////
    /// GETTERS ////
    ////////////////
}
