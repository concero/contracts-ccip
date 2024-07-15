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

contract Infra is Test {
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
    Orchestrator wInfraSrc;
    Orchestrator wInfraDst;
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
    IRouter aerodromeRouterArb;

    //==== Instantiate Chainlink Forked CCIP
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint64 baseChainSelector = 10344971235874465080;
    uint64 arbChainSelector = 4949039107694359620;

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

    address ProxyOwner = makeAddr("ProxyOwner");
    address Tester = makeAddr("Tester");
    address User = makeAddr("User");
    address Messenger = makeAddr("Messenger");
    address LP = makeAddr("LiquidityProvider");
    address DummyAddress = makeAddr("DummyAddress");
    address MockAddress = makeAddr("MockAddress");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 baseTestnetFork;
    uint256 arbitrumMainFork;
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant LINK_BALANCE = 1 ether;
    uint256 constant USDC_INITIAL_BALANCE = 10 * 10**6;
    uint256 constant LP_INITIAL_BALANCE = 2 ether;
    ERC721 SAFE_LOCK;

    function setUp() public {
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
            15, //_subscriptionId
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
            15,
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

        //====== Wrap the proxy as the implementation
        wInfraSrc = Orchestrator(address(proxy));
        wMaster = ParentPool(payable(address(masterProxy)));

        //====== Update the MINTER on the LP Token
        // vm.prank(Tester);
        // lp.grantRole(keccak256("MINTER_ROLE"), address(wMaster));
        }
    }

    error StorageSetters_CallableOnlyByOwner(address, address);

    // setDexRouterAddress
    event Storage_NewRouterAdded(address, uint256);
    function test_setDexRouterAddress() public {
        vm.prank(defaultSender);
        vm.expectEmit();
        emit Storage_NewRouterAdded(DummyAddress, 1);
        wInfraSrc.setDexRouterAddress( DummyAddress, 1);

        vm.assertEq(wInfraSrc.s_routerAllowed(DummyAddress), 1);
    }

    function test_revertSetDexRouterAddress() public {
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setDexRouterAddress( DummyAddress, 1);

        vm.assertEq(wInfraSrc.s_routerAllowed(DummyAddress), 0);
    }

    // setClfPremiumFees
    event CLFPremiumFeeUpdated(uint64, uint256, uint256);
    function test_setClfPremiumFees() public {
        uint256 previousValue = 0;
        uint256 feeAmount = 1847290640394088;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit CLFPremiumFeeUpdated(baseChainSelector, previousValue, feeAmount);
        wInfraSrc.setClfPremiumFees(baseChainSelector, feeAmount);

        assertEq(wInfraSrc.clfPremiumFees(baseChainSelector), feeAmount);
    }

    function test_revertSetClfPremiumFees() public {
        uint256 previousValue = 0;
        uint256 feeAmount = 1847290640394088;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setClfPremiumFees(baseChainSelector, feeAmount);

        assertEq(wInfraSrc.clfPremiumFees(baseChainSelector), previousValue);
    }

    // setConceroContract
    event ConceroContractUpdated(uint64, address);
    function test_infraSetConceroContract() public {
        vm.prank(defaultSender);
        vm.expectEmit();
        emit ConceroContractUpdated(arbChainSelector, address(concero));
        wInfraSrc.setConceroContract(arbChainSelector, address(concero));

        assertEq(wInfraSrc.s_conceroContracts(arbChainSelector), address(concero));
    }

    function test_revertInfraSetConceroContract() public {
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setConceroContract(arbChainSelector, address(concero));

        assertEq(wInfraSrc.s_conceroContracts(arbChainSelector), address(0));
    }

    // setDonHostedSecretsVersion
    event DonSecretVersionUpdated(uint64 previousValue, uint64 newVersion);
    function test_infraSetDonHostedSecretsVersion() public {
        uint64 previousValue = 0;
        uint64 newVersion = 10;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit DonSecretVersionUpdated(previousValue, newVersion);
        wInfraSrc.setDonHostedSecretsVersion(newVersion);

        assertEq(wInfraSrc.s_donHostedSecretsVersion(), newVersion);
    }

    function test_revertInfraSetDonHostedSecretsVersion() public {
        uint64 newVersion = 10;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setDonHostedSecretsVersion(newVersion);

        assertEq(wInfraSrc.s_donHostedSecretsVersion(), 0);
    }

    // SetDonHostedSecretsSlotID
    event DonSlotIdUpdated(uint8 previousValue, uint8 newVersion);
    function test_SetDonHostedSecretsSlotID() public {
        uint8 previousValue = 0;
        uint8 newVersion = 1;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit DonSlotIdUpdated(previousValue, newVersion);
        wInfraSrc.setDonHostedSecretsSlotID(newVersion);

        assertEq(wInfraSrc.s_donHostedSecretsSlotId(), newVersion);
    }

    function test_revertSetDonHostedSecretsSlotID() public {
        uint8 previousValue = 0;
        uint8 newVersion = 1;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setDonHostedSecretsSlotID(newVersion);

        assertEq(wInfraSrc.s_donHostedSecretsSlotId(), previousValue);
    }

    // SetDstJsHashSum
    event DestinationJsHashSumUpdated(bytes32, bytes32);
    function test_SetDstJsHashSum() public {
        bytes32 previousHashSum = 0;
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit DestinationJsHashSumUpdated(previousHashSum, hashSum);
        wInfraSrc.setDstJsHashSum(hashSum);

        assertEq(wInfraSrc.s_dstJsHashSum(), hashSum);
    }

    function test_revertSetDstJsHashSum() public {
        bytes32 previousHashSum = 0;
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setDstJsHashSum(hashSum);
        
        assertEq(wInfraSrc.s_dstJsHashSum(), previousHashSum);
    }

    // SetSrcJsHashSum
    event SourceJsHashSumUpdated(bytes32, bytes32);    
    function test_setSrcJsHashSum() public {
        bytes32 previousHashSum = 0;
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit SourceJsHashSumUpdated(previousHashSum, hashSum);
        wInfraSrc.setSrcJsHashSum(hashSum);

        assertEq(wInfraSrc.s_srcJsHashSum(), hashSum);

    }

    function test_revertSetSrcJsHashSum() public {
        bytes32 previousHashSum = 0;
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setSrcJsHashSum(hashSum);
        
        assertEq(wInfraSrc.s_srcJsHashSum(), previousHashSum);
    }

    // SetEthersHashSum
    event EthersHashSumUpdated(bytes32, bytes32);  
    function test_setEthersHashSum() public {
        bytes32 previousHashSum = 0;
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        vm.prank(defaultSender);
        vm.expectEmit();
        emit EthersHashSumUpdated(previousHashSum, hashSum);
        wInfraSrc.setEthersHashSum(hashSum);

        assertEq(wInfraSrc.s_ethersHashSum(), hashSum);

    }

    function test_revertSetEthersHashSum() public {
        bytes32 previousHashSum = 0;
        bytes32 hashSum = 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setEthersHashSum(hashSum);
        
        assertEq(wInfraSrc.s_ethersHashSum(), previousHashSum);
    }

    // SetDstConceroPool
    function test_setConceroPool() public {
        vm.prank(defaultSender);
        wInfraSrc.setDstConceroPool(arbChainSelector, MockAddress);

        assertEq(wInfraSrc.s_poolReceiver(arbChainSelector), MockAddress);
    }

    function test_revertSetConceroPool() public {
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(StorageSetters_CallableOnlyByOwner.selector, Tester, defaultSender));
        wInfraSrc.setDstConceroPool(arbChainSelector, MockAddress);

        assertEq(wInfraSrc.s_poolReceiver(arbChainSelector), address(0));
    }
} 