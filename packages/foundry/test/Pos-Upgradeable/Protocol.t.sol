// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

//Foundry
import {Test, console} from "forge-std/Test.sol";

//Protocol Contacts
import {DexSwap} from "contracts/DexSwap.sol";
import {ConceroPool} from "contracts/ConceroPool.sol";
import {Concero} from "contracts/Concero.sol";
import {Orchestrator} from "contracts/Orchestrator.sol";
import {ConceroProxy} from "contracts/ConceroProxy.sol";

//Interfaces
import {IDexSwap} from "contracts/Interfaces/IDexSwap.sol";
import {IStorage} from "contracts/Interfaces/IStorage.sol";

//Protocol Storage
import {Storage} from "contracts/Libraries/Storage.sol";

//Deploy Scripts
import {DexSwapDeploy} from "../../script/DexSwapDeploy.s.sol";
import {ConceroPoolDeploy} from "../../script/ConceroPoolDeploy.s.sol";
import {ConceroDeploy} from "../../script/ConceroDeploy.s.sol";
import {OrchestratorDeploy} from "../../script/OrchestratorDeploy.s.sol";
import {TransparentDeploy} from "../../script/TransparentDeploy.s.sol";

//Mocks
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

//OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//DEXes routers
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {IRouter} from "velodrome/contracts/interfaces/IRouter.sol";
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {ISwapRouter02, IV3SwapRouter} from "contracts/Interfaces/ISwapRouter02.sol";

//Chainlink
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract ProtocolTest is Test {
    //==== Instantiate Base Contracts
    DexSwap public dex;
    ConceroPool public pool;
    Concero public concero;
    Orchestrator public orch;
    Orchestrator public orchEmpty;
	ConceroProxy public proxy;

    //==== Instantiate Arbitrum Contracts
    DexSwap public dexDst;
    ConceroPool public poolDst;
    Concero public conceroDst;
    Orchestrator public orchDst;
    Orchestrator public orchEmptyDst;
	ConceroProxy public proxyDst;

    //==== Instantiate Deploy Script
    DexSwapDeploy dexDeploy;
    ConceroPoolDeploy poolDeploy;
    ConceroDeploy conceroDeploy;
    OrchestratorDeploy orchDeploy;
    TransparentDeploy proxyDeploy;

    //==== Wrapped contract
    Orchestrator op;
    Orchestrator opDst;

    //==== Create the instance to forked tokens
    IWETH wEth;
    IWETH arbWEth;
    IERC20 public mUSDC;
    IERC20 public aUSDC;
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
    uint64 baseChainSelector = 15971525489660198786;
    uint64 arbChainSelector = 4949039107694359620;

    //Base Mainnet variables
    address linkBase = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address ccipRouterBase = 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;
    uint64 ccipChainSelectorBase = 15971525489660198786;
    address functionsRouterBase = 0xf9B8fc078197181C841c296C876945aaa425B278;
    bytes32 donIdBase = 0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000;

    //Base Mainnet variables
    address linkArb = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address ccipRouterArb = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    uint64 ccipChainSelectorArb = 4949039107694359620;
    address functionsRouterArb = 0x97083E831F8F0638855e2A515c90EdCF158DF238;
    bytes32 donIdArb = 0x66756e2d617262697472756d2d6d61696e6e65742d3100000000000000000000;

    ERC20Mock tUSDC;

    address User = makeAddr("User");
    address Tester = makeAddr("Tester");
    address Messenger = makeAddr("Messenger");
    address LP = makeAddr("LiquidityProvider");
    address defaultSender = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

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
        baseMainFork = vm.createFork(BASE_RPC_URL);
        arbitrumMainFork = vm.createFork(ARB_RPC_URL);
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        //Base Network details
        Register.NetworkDetails memory base = Register.NetworkDetails({
            chainSelector: baseChainSelector,
            routerAddress: ccipRouterBase,
            linkAddress: linkBase,
            wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
            ccipBnMAddress: address(0),
            ccipLnMAddress: address(0)
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
            ccipBnMAddress: address(0),
            ccipLnMAddress: address(0)
        });

        ccipLocalSimulatorFork.setNetworkDetails(
            42161,
            arbitrum
        );

        //Base Routers
        uniswapV2 = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        sushiV2 = IUniswapV2Router02(0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891);
        uniswapV3 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
        sushiV3 = ISwapRouter(0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f);
        aerodromeRouter = IRouter(0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43);

        //Arbitrum Routers
        uniswapV2Arb = IUniswapV2Router02(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        sushiV2Arb = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        uniswapV3Arb = ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
        sushiV3Arb = ISwapRouter(0x8A21F6768C1f8075791D08546Dadf6daA0bE820c);

        wEth = IWETH(0x4200000000000000000000000000000000000006);
        arbWEth = IWETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        mUSDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        aUSDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        AERO = ERC20Mock(0x940181a94A35A4569E4529A3CDfB74e38FD98631);
        SAFE_LOCK = ERC721(0xde11Bc6a6c47EeaB0476C85672EA7f932f1a78Ed);

        dexDeploy = new DexSwapDeploy();
        poolDeploy = new ConceroPoolDeploy();
        conceroDeploy = new ConceroDeploy();
        orchDeploy = new OrchestratorDeploy();
        proxyDeploy = new TransparentDeploy();

        {
        vm.selectFork(baseMainFork);
        //DEPLOY AN EMPTY ORCH
        orchEmpty = orchDeploy.run(
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            1,
            0
        );
        //====== Deploy the proxy with the Dummy Orch
        proxy = proxyDeploy.run(address(orchEmpty), Tester, "");

        dex = dexDeploy.run(address(proxy));
        pool = poolDeploy.run(
            linkBase,
            ccipRouterBase,
            address(proxy)
        );
        concero = conceroDeploy.run(
           IStorage.FunctionsVariables ({
                donHostedSecretsSlotId: 2, //uint8 _donHostedSecretsSlotId
                donHostedSecretsVersion: 0, //uint64 _donHostedSecretsVersion
                subscriptionId: 0, //uint64 _subscriptionId,
                donId: donIdBase,
                functionsRouter: functionsRouterBase
            }),
            ccipChainSelectorBase,
            1, //uint _chainIndex,
            linkBase,
            ccipRouterBase,
            address(dex),
           IStorage.JsCodeHashSum ({
                src: 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124,
                dst: 0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173
            }),
            0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124, //_ethersHashSum
            address(pool),
            address(proxy)
        );
        orch = orchDeploy.run(
            functionsRouterBase,
            address(dex),
            address(concero),
            address(pool),
            address(proxy),
            1,
            ccipChainSelectorBase
        );

        //=== Base Contracts
        vm.makePersistent(address(proxy));
        vm.makePersistent(address(dex));
        vm.makePersistent(address(pool));
        vm.makePersistent(address(concero));
        vm.makePersistent(address(orch));
        vm.makePersistent(address(ccipLocalSimulatorFork));

        //=== Transfer ownership to Tester
        vm.startPrank(defaultSender);
        dex.transferOwnership(Tester);
        pool.transferOwnership(Tester);
        concero.transferOwnership(Tester);
        orch.transferOwnership(Tester);
        proxy.transferOwnership(Tester);
        vm.stopPrank();

        //====== Update the proxy for the correct address
        vm.prank(Tester);
        proxy.upgradeTo(address(orch));

        //====== Wrap the proxy as the implementation
        op = Orchestrator(address(proxy));

        //====== Set the DEXes routers
        vm.startPrank(Tester);
        op.manageRouterAddress(address(uniswapV2), 1);
        op.manageRouterAddress(address(sushiV2), 1);
        op.manageRouterAddress(address(uniswapV3), 1);
        op.manageRouterAddress(address(sushiV3), 1);
        op.manageRouterAddress(address(aerodromeRouter), 1);

        //====== Set the Messenger to be allowed to interact
        pool.setConceroMessenger(Messenger, 1);
        concero.setConceroMessenger(Messenger, 1);

        pool.setConceroPoolReceiver(arbChainSelector ,address(poolDst));

        pool.setConceroContractSender(arbChainSelector, address(poolDst), 1);
        pool.setConceroContractSender(arbChainSelector, address(conceroDst), 1);

        pool.setSupportedToken(address(mUSDC), 1);
        pool.setApprovedSender(address(mUSDC), LP);

        concero.setConceroContract(arbChainSelector, address(proxyDst));
        vm.stopPrank();
        }

        //================ SWITCH CHAINS ====================\\

        {
        vm.selectFork(arbitrumMainFork);
        //DEPLOY AN EMPTY ORCH
        orchEmptyDst = orchDeploy.run(
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            0,
            0
        );
        //====== Deploy the proxy with the Dummy Orch
        proxyDst = proxyDeploy.run(address(orchEmptyDst), Tester, "");

        dexDst = dexDeploy.run(address(proxyDst));
        poolDst = poolDeploy.run(
            linkArb,
            ccipRouterArb,
            address(proxyDst)
        );
        conceroDst = conceroDeploy.run(
           IStorage.FunctionsVariables ({
                donHostedSecretsSlotId: 2, //uint8 _donHostedSecretsSlotId
                donHostedSecretsVersion: 0, //uint64 _donHostedSecretsVersion
                subscriptionId: 0, //uint64 _subscriptionId,
                donId: donIdArb,
                functionsRouter: functionsRouterArb
            }),
            ccipChainSelectorArb,
            1, //uint _chainIndex,
            linkArb,
            ccipRouterArb,
            address(dexDst),
           IStorage.JsCodeHashSum ({
                src: 0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124,
                dst: 0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173
            }),
            0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173, //_ethersHashSum
            address(poolDst),
            address(proxyDst)
        );

        orchDst = orchDeploy.run(
            functionsRouterArb,
            address(dexDst),
            address(conceroDst),
            address(poolDst),
            address(proxyDst),
            0,
            ccipChainSelectorArb
        );

        //=== Arbitrum Contracts
        vm.makePersistent(address(proxyDst));
        vm.makePersistent(address(dexDst));
        vm.makePersistent(address(poolDst));
        vm.makePersistent(address(conceroDst));
        vm.makePersistent(address(orchDst));
        vm.makePersistent(address(ccipLocalSimulatorFork));

        //=== Transfer ownership to Tester
        vm.startPrank(defaultSender);
        dexDst.transferOwnership(Tester);
        poolDst.transferOwnership(Tester);
        conceroDst.transferOwnership(Tester);
        orchDst.transferOwnership(Tester);
        proxyDst.transferOwnership(Tester);
        vm.stopPrank();

        //====== Update the proxy for the correct address
        vm.prank(Tester);
        proxyDst.upgradeTo(address(orchDst));

        //====== Wrap the proxy as the implementation
        opDst = Orchestrator(address(proxyDst));

        //====== Set the DEXes routers
        vm.startPrank(Tester);
        opDst.manageRouterAddress(address(uniswapV2Arb), 1);
        opDst.manageRouterAddress(address(sushiV2Arb), 1);
        opDst.manageRouterAddress(address(uniswapV3Arb), 1);
        opDst.manageRouterAddress(address(sushiV3Arb), 1);
        opDst.manageRouterAddress(address(aerodromeRouterArb), 1);

        //====== Set the Messenger to be allowed to interact
        poolDst.setConceroMessenger(Messenger, 1);
        conceroDst.setConceroMessenger(Messenger, 1);

        poolDst.setConceroPoolReceiver(baseChainSelector ,address(pool));

        poolDst.setConceroContractSender(baseChainSelector, address(pool), 1);
        poolDst.setConceroContractSender(baseChainSelector, address(concero), 1);

        poolDst.setSupportedToken(address(mUSDC), 1);
        poolDst.setApprovedSender(address(mUSDC), LP);
        poolDst.setSupportedToken(address(aUSDC), 1);
        poolDst.setApprovedSender(address(aUSDC), LP);

        conceroDst.setConceroContract(baseChainSelector, address(proxy));
        vm.stopPrank();
        }
    }

    function helper() public {
        // select the fork
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

        vm.startPrank(Tester);
        assertEq(proxy.implementation(), address(orch));

        proxy.upgradeTo(address(SAFE_LOCK));

        assertEq(proxy.implementation(), address(SAFE_LOCK));
        vm.stopPrank();
    }

    /// TEST SAFE LOCK ///
    error Proxy_ContractPaused();
    function test_safeLockAndRevertOnCall() public {
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

        vm.startPrank(Tester);
        assertEq(proxy.implementation(), address(orch));

        proxy.upgradeTo(address(SAFE_LOCK));

        assertEq(proxy.implementation(), address(SAFE_LOCK));
        vm.stopPrank();

        op = Orchestrator(address(proxy));

        uint amountIn = 1*10**17;
        uint amountOutMin = 350*10**5;
        address[] memory path = new address[](2);
        path[0] = address(wEth);
        path[1] = address(mUSDC);
        address to = User;
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
                            dexData: abi.encode(sushiV2, path, to, deadline)
                        });

        // ==== Approve Transfer
        vm.startPrank(User);
        wEth.approve(address(op), 0.1 ether);

        //==== Initiate transaction
        vm.expectRevert(abi.encodeWithSelector(Proxy_ContractPaused.selector));
        op.swap(swapData);
    }

    function test_AdminCanUpdatedImplementationAfterSafeLock() public {
        //====== Chose the Fork Network
        vm.selectFork(baseMainFork);
        assertEq(vm.activeFork(), baseMainFork);

        vm.startPrank(Tester);
        //====== Checks for the initial implementation
        assertEq(proxy.implementation(), address(orch));

        //====== Upgrades it to SAFE_LOCK
        proxy.upgradeTo(address(SAFE_LOCK));

        //====== Verify if the upgrade happen as expected
        assertEq(proxy.implementation(), address(SAFE_LOCK));

        //====== Upgrades it again to a valid address
        proxy.upgradeTo(address(orch));

        //====== Checks if the upgrade happens as expected
        assertEq(proxy.implementation(), address(orch));

        vm.stopPrank();
    }
}
