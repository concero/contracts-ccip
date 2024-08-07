//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.20;
//
//import {Test, console2} from "forge-std/Test.sol";
//import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
//
//import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
//import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";
//import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";
//
//import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
//import {LPToken} from "contracts/LPToken.sol";
//
//import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";
//
//import {USDC} from "../../Mocks/USDC.sol";
//
//
//contract ParentPoolTest is Test {
//    //==== Instantiate Contracts
//    ConceroParentPool public masterPool;
//    LPToken public lp;
//
//    //==== Instantiate Proxies
//    ParentPoolProxy masterProxy;
//    ITransparentUpgradeableProxy proxyInterfaceMaster;
//
//    //==== Instantiate Deploy Script
//    ParentPoolDeploy public masterDeploy;
//    LPTokenDeploy public lpDeploy;
//    ParentPoolProxyDeploy masterProxyDeploy;
//
//    //==== Wrapped contract
//    ConceroParentPool wMaster;
//
//    //======= Instantiate Mock
//    USDC public usdc;
//
//    uint256 private constant INITIAL_BALANCE = 10 ether;
//    uint256 private constant USDC_INITIAL_BALANCE = 150 * 10**6;
//
//    address proxyOwner = makeAddr("owner");
//    address Tester = makeAddr("Tester");
//    address Athena = makeAddr("Athena");
//    address Orchestrator = makeAddr("Orchestrator");
//    address Messenger = makeAddr("Messenger");
//
//    uint64 mockDestinationChainSelector = 5161349165154982;
//    address mockLinkTokenAddress = makeAddr("0x01");
//    address mockSourceRouter = makeAddr("0x02");
//    address mockLPTokenAddress = makeAddr("0x03");
//    address mockAutomationAddress = makeAddr("0x04");
//    address mockFunctionsRouter = makeAddr("0x08");
//
//    address mockChildPoolAddress = makeAddr("0x05");
//    address mockConceroContractAddress = makeAddr("0x06");
//
//    bytes32 public constant PROJECT_OWNER = keccak256("PROJECT_OWNER");
//    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
//    bytes32 public constant CONTRACT_MANAGER = keccak256 ("CONTRACT_MANAGER");
//    bytes32 public constant WHITE_LIST_MANAGER = keccak256 ("WHITE_LIST_MANAGER");
//    bytes32 public constant WHITE_LISTED = keccak256("WHITE_LISTED");
//
//    function setUp() public {
//        //======= Deploy Scripts
//        masterProxyDeploy = new ParentPoolProxyDeploy();
//        masterDeploy = new ParentPoolDeploy();
//        lpDeploy = new LPTokenDeploy();
//
//        //======= Deploy Mock
//        usdc = new USDC("USDC", "USDC", Tester, USDC_INITIAL_BALANCE);
//
//        //======= Deploy proxies
//        masterProxy = masterProxyDeploy.run(address(lpDeploy), proxyOwner, "");
//
//        //======= Wraps on the interface to update later
//        proxyInterfaceMaster = ITransparentUpgradeableProxy(address(masterProxy));
//
//        //======= Liquidity Provider
//        lp = lpDeploy.run(Tester, address(masterProxy));
//
//        //======= Deploy MasterPool
//        masterPool = masterDeploy.run(
//            address(masterProxy),
//            mockLinkTokenAddress,
//            0,
//            0,
//            mockFunctionsRouter,
//            mockSourceRouter,
//            address(usdc),
//            address(lp),
//            mockAutomationAddress,
//            Orchestrator,
//            Tester
//        );
//
//        vm.prank(proxyOwner);
//        proxyInterfaceMaster.upgradeToAndCall(address(masterPool), "");
//
//        vm.prank(Tester);
//        lp.grantRole(keccak256("CONTRACT_MANAGER"), Athena);
//        vm.prank(Tester);
//        lp.grantRole(keccak256("MINTER_ROLE"), address(masterPool));
//
//        wMaster = ConceroParentPool(payable(address(masterProxy)));
//    }
//
//    ///////////////////////////////////////////////////////////////
//    ////////////////////////Admin Functions////////////////////////
//    ///////////////////////////////////////////////////////////////
//    ///setConceroContractSender///
//    event ConceroParentPool_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256);
//    function test_setConceroContractSender() public {
//        vm.prank(Tester);
//        vm.expectEmit();
//        emit ConceroParentPool_ConceroSendersUpdated(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
//        wMaster.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
//
//        assertEq(wMaster.s_contractsToReceiveFrom(mockDestinationChainSelector, address(mockChildPoolAddress)), 1);
//    }
//
//    error ConceroParentPool_NotContractOwner();
//    error ConceroParentPool_InvalidAddress();
//    function test_revertSetParentPool() public {
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_NotContractOwner.selector));
//        wMaster.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
//
//        vm.prank(Tester);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InvalidAddress.selector));
//        wMaster.setConceroContractSender(mockDestinationChainSelector, address(0), 1);
//    }
//
//    //setPools///
//    event ConceroParentPool_PoolReceiverUpdated(uint64 chainSelector, address contractAddress);
//    function test_setPools() public {
//        vm.prank(Tester);
//        vm.expectEmit();
//        emit ConceroParentPool_PoolReceiverUpdated(mockDestinationChainSelector, address(mockChildPoolAddress));
//        wMaster.setPools(mockDestinationChainSelector, address(mockChildPoolAddress), false);
//
//        assertEq(wMaster.s_poolToSendTo(mockDestinationChainSelector), address(mockChildPoolAddress));
//    }
//
//    event ConceroParentPool_RedistributionStarted(bytes32);
//    function test_revertSetPools() public {
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_NotContractOwner.selector));
//        wMaster.setPools(mockDestinationChainSelector, address(mockChildPoolAddress), false);
//
//        vm.prank(Tester);
//        vm.expectEmit();
//        emit ConceroParentPool_PoolReceiverUpdated(mockDestinationChainSelector, address(mockChildPoolAddress));
//        emit ConceroParentPool_RedistributionStarted(0); //requestId == 0 because CLF is disabled.
//        wMaster.setPools(mockDestinationChainSelector, address(mockChildPoolAddress), true);
//
//        vm.prank(Tester);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InvalidAddress.selector));
//        wMaster.setPools(mockDestinationChainSelector, address(mockChildPoolAddress), false);
//
//        vm.prank(Tester);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InvalidAddress.selector));
//        wMaster.setPools(mockDestinationChainSelector, address(0), false);
//    }
//
//    //Need to Refactor after changes
//    // function test_distributeLiquidity() public {
//    //     uint64 fakeChainSelector = 15165481213213213;
//    //     bytes32 distributeLiquidityRequestId = keccak256(
//    //         abi.encodePacked(_pool, fakeChainSelector, ConceroParentPool.DistributeLiquidityType.addPool, block.timestamp, block.number, block.prevrandao)
//    //     );
//    //     vm.prank(Messenger);
//    //     vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InvalidAddress.selector));
//    //     wMaster.distributeLiquidity(fakeChainSelector, 10*10**6, distributeLiquidityRequestId);
//    // }
//
//    ///takeLoan///
//    error ConceroParentPool_ItsNotOrchestrator(address);
//    error ConceroParentPool_InsufficientBalance();
//    event ConceroParentPool_SuccessfulDeposited(address, uint256, address);
//    error ConceroParentPool_CallerIsNotTheProxy(address);
//    function test_orchestratorLoanRevert() external {
//
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_ItsNotOrchestrator.selector, address(this)));
//        wMaster.takeLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));
//
//        vm.startPrank(Orchestrator);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InvalidAddress.selector));
//        wMaster.takeLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));
//
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InsufficientBalance.selector));
//        wMaster.takeLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));
//
//        vm.startPrank(Orchestrator);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_CallerIsNotTheProxy.selector, address(masterPool)));
//        masterPool.takeLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));
//        vm.stopPrank();
//
//        vm.prank(Tester);
//        usdc.transfer(address(wMaster), USDC_INITIAL_BALANCE);
//        vm.prank(Orchestrator);
//        wMaster.takeLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));
//
//    }
//
//    //It will revert on ccip call
//    function test_depositLiquidityWithZeroCap() public {
//        uint256 allowedAmountToDeposit = 150*10**6;
//
//        //===== Add a Fake pool
//        vm.prank(Tester);
//        wMaster.setPools(mockDestinationChainSelector, mockChildPoolAddress, false);
//
//        //===== Cap is Zero
//        vm.prank(Tester);
//        usdc.approve(address(wMaster), allowedAmountToDeposit);
//
//        uint256 capNow = wMaster.getMaxDeposit();
//        assertEq(capNow, 0);
//
//        //CCIP being called means deposit went through, so the purpose is fulfilled
//        vm.prank(Tester);
//        vm.expectRevert();
//        wMaster.startDeposit(allowedAmountToDeposit);
//
//        uint256 inUse = wMaster.getUsdcInUse();
//        assertEq(inUse, 0);
//    }
//
//    error ConceroParentPool_AmountBelowMinimum(uint256 amount);
//    error ConceroParentPool_ThereIsNoPoolToDistribute();
//    error ConceroParentPool_MaxCapReached(uint256);
//    event ConceroParentPool_MasterPoolCapUpdated(uint256);
//    function test_depositLiquidityRevert() public {
//        uint256 allowedAmountToDeposit = 150*10**6;
//
//        vm.prank(Tester);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_ThereIsNoPoolToDistribute.selector));
//        wMaster.depositLiquidity(allowedAmountToDeposit);
//
//        vm.prank(Tester);
//        wMaster.setPools(mockDestinationChainSelector, mockChildPoolAddress, false);
//
//        // vm.prank(Tester);
//        // vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_AmountBelowMinimum.selector, 100*10**6));
//        // wMaster.depositLiquidity(amountToDeposit);
//
//        vm.prank(Tester);
//        wMaster.setPoolCap(120 *10**6);
//
//        vm.prank(Tester);
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_MaxCapReached.selector, 120 *10**6));
//        wMaster.depositLiquidity(allowedAmountToDeposit);
//
//        vm.prank(Tester);
//        vm.expectEmit();
//        emit ConceroParentPool_MasterPoolCapUpdated(allowedAmountToDeposit);
//        wMaster.setPoolCap(allowedAmountToDeposit);
//    }
//
//    event ConceroParentPool_ChainAndAddressRemoved(uint64 chainSelector);
//    function test_removePoolFromArray() public {
//        vm.prank(Tester);
//        wMaster.setPools(mockDestinationChainSelector, address(mockChildPoolAddress), false);
//
//        vm.prank(Tester);
//        vm.expectEmit();
//        emit ConceroParentPool_ChainAndAddressRemoved(mockDestinationChainSelector);
//        emit ConceroParentPool_RedistributionStarted(0); //requestId == 0 because CLF is disabled
//        wMaster.removePools(mockDestinationChainSelector);
//    }
//
//    function test_startWithdrawRevert() public {
//        vm.expectRevert(abi.encodeWithSelector(ConceroParentPool_InsufficientBalance.selector));
//        wMaster.startWithdrawal(10*10**18);
//    }
//
//}
