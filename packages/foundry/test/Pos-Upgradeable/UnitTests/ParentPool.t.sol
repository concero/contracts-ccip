// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {ParentPoolDeploy} from "../../../script/ParentPoolDeploy.s.sol";
import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";
import {ParentPoolProxyDeploy} from "../../../script/ParentPoolProxyDeploy.s.sol";

import {ParentPool} from "contracts/ParentPool.sol";
import {LPToken} from "contracts/LPToken.sol";

import {ParentPoolProxy} from "contracts/Proxy/ParentPoolProxy.sol";

import {USDC} from "../../Mocks/USDC.sol";


contract ParentPoolTest is Test {
    //==== Instantiate Contracts
    ParentPool public masterPool;
    LPToken public lp;
    
    //==== Instantiate Proxies
    ParentPoolProxy masterProxy;
    ITransparentUpgradeableProxy proxyInterfaceMaster;

    //==== Instantiate Deploy Script
    ParentPoolDeploy public masterDeploy;
    LPTokenDeploy public lpDeploy;
    ParentPoolProxyDeploy masterProxyDeploy;

    //==== Wrapped contract
    ParentPool wMaster;

    //======= Instantiate Mock
    USDC public usdc;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant USDC_INITIAL_BALANCE = 150 * 10**6;

    address proxyOwner = makeAddr("owner");
    address Tester = makeAddr("Tester");
    address Athena = makeAddr("Athena");
    address Orchestrator = makeAddr("Orchestrator");
    address Messenger = makeAddr("Messenger");

    uint64 mockDestinationChainSelector = 5161349165154982;
    address mockLinkTokenAddress = makeAddr("0x01");
    address mockSourceRouter = makeAddr("0x02");
    address mockLPTokenAddress = makeAddr("0x03");
    address mockAutomationAddress = makeAddr("0x04");
    address mockFunctionsRouter = makeAddr("0x08");

    address mockChildPoolAddress = makeAddr("0x05");
    address mockConceroContractAddress = makeAddr("0x06");

    bytes32 public constant PROJECT_OWNER = keccak256("PROJECT_OWNER");
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant CONTRACT_MANAGER = keccak256 ("CONTRACT_MANAGER");
    bytes32 public constant WHITE_LIST_MANAGER = keccak256 ("WHITE_LIST_MANAGER");
    bytes32 public constant WHITE_LISTED = keccak256("WHITE_LISTED");

    function setUp() public {
        //======= Deploy Scripts
        masterProxyDeploy = new ParentPoolProxyDeploy();
        masterDeploy = new ParentPoolDeploy();
        lpDeploy = new LPTokenDeploy();

        //======= Deploy Mock
        usdc = new USDC("USDC", "USDC", Tester, USDC_INITIAL_BALANCE);

        //======= Deploy proxies
        masterProxy = masterProxyDeploy.run(address(lpDeploy), proxyOwner, "");

        //======= Wraps on the interface to update later 
        proxyInterfaceMaster = ITransparentUpgradeableProxy(address(masterProxy));

        //======= Liquidity Provider
        lp = lpDeploy.run(Tester, address(masterProxy));

        //======= Deploy MasterPool
        masterPool = masterDeploy.run(
            address(masterProxy),
            mockLinkTokenAddress,
            0,
            0,
            mockFunctionsRouter,
            mockSourceRouter,
            address(usdc),
            address(lp),
            mockAutomationAddress,
            Orchestrator,
            Tester
        );

        vm.prank(proxyOwner);
        proxyInterfaceMaster.upgradeToAndCall(address(masterPool), "");

        vm.prank(Tester);
        lp.grantRole(keccak256("CONTRACT_MANAGER"), Athena);
        vm.prank(Tester);
        lp.grantRole(keccak256("MINTER_ROLE"), address(masterPool));

        wMaster = ParentPool(payable(address(masterProxy)));
    }

    ///////////////////////////////////////////////////////////////
    ////////////////////////Admin Functions////////////////////////
    ///////////////////////////////////////////////////////////////
    ///setConceroContractSender///
    event ParentPool_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256);
    function test_setParentPool() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit ParentPool_ConceroSendersUpdated(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
        wMaster.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);

        assertEq(wMaster.s_contractsToReceiveFrom(mockDestinationChainSelector, address(mockChildPoolAddress)), 1);
    }

    error ParentPool_NotContractOwner();
    error ParentPool_InvalidAddress();
    function test_revertSetParentPool() public {
        vm.expectRevert(abi.encodeWithSelector(ParentPool_NotContractOwner.selector));
        wMaster.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
        
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_InvalidAddress.selector));
        wMaster.setConceroContractSender(mockDestinationChainSelector, address(0), 1);
    }

    //setParentPoolReceiver///
    event ParentPool_PoolReceiverUpdated(uint64 chainSelector, address contractAddress);
    function test_setParentPoolReceiver() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit ParentPool_PoolReceiverUpdated(mockDestinationChainSelector, address(mockChildPoolAddress));
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));

        assertEq(wMaster.s_poolToSendTo(mockDestinationChainSelector), address(mockChildPoolAddress));
    }

    function test_revertSetParentPoolReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(ParentPool_NotContractOwner.selector));
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));
        
        vm.prank(Tester);
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_InvalidAddress.selector));
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));
        
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_InvalidAddress.selector));
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(0));
    }

    ///orchestratorLoan///
    error ParentPool_ItsNotOrchestrator(address);
    error ParentPool_InsufficientBalance();
    event ParentPool_SuccessfulDeposited(address, uint256, address);
    error ParentPool_CallerIsNotTheProxy(address);
    function test_orchestratorLoanRevert() external {

        vm.expectRevert(abi.encodeWithSelector(ParentPool_ItsNotOrchestrator.selector, address(this)));
        wMaster.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));

        vm.startPrank(Orchestrator);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_InvalidAddress.selector));
        wMaster.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));

        vm.expectRevert(abi.encodeWithSelector(ParentPool_InsufficientBalance.selector));
        wMaster.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));

        vm.startPrank(Orchestrator);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_CallerIsNotTheProxy.selector, address(masterPool)));
        masterPool.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));

        vm.stopPrank();
    }

    //It will revert on ccip call
    function test_depositLiquidityWithZeroCap() public {
        uint256 allowedAmountToDeposit = 150*10**6;
        
        //===== Add a Fake pool
        vm.prank(Tester);
        wMaster.setPoolsToSend(mockDestinationChainSelector, mockChildPoolAddress);

        //===== Cap is Zero
        vm.prank(Tester);
        usdc.approve(address(wMaster), allowedAmountToDeposit);

        //CCIP being called means deposit went through, so the purpose is fulfilled
        vm.prank(Tester);
        vm.expectRevert();
        wMaster.depositLiquidity(allowedAmountToDeposit);
    }

    error ParentPool_AmountBelowMinimum(uint256 amount);
    error ParentPool_ThereIsNoPoolToDistribute();
    error ParentPool_MaxCapReached(uint256);
    event ParentPool_MasterPoolCapUpdated(uint256);
    function test_depositLiquidityRevert() public {
        uint256 allowedAmountToDeposit = 150*10**6;
        
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_ThereIsNoPoolToDistribute.selector));
        wMaster.depositLiquidity(allowedAmountToDeposit);

        vm.prank(Tester);
        wMaster.setPoolsToSend(mockDestinationChainSelector, mockChildPoolAddress);

        // vm.prank(Tester);
        // vm.expectRevert(abi.encodeWithSelector(ParentPool_AmountBelowMinimum.selector, 100*10**6));
        // wMaster.depositLiquidity(amountToDeposit);

        vm.prank(Tester);
        wMaster.setPoolCap(120 *10**6);

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ParentPool_MaxCapReached.selector, 120 *10**6));
        wMaster.depositLiquidity(allowedAmountToDeposit);

        vm.prank(Tester);
        vm.expectEmit();
        emit ParentPool_MasterPoolCapUpdated(allowedAmountToDeposit);
        wMaster.setPoolCap(allowedAmountToDeposit);
    }

    event ParentPool_ChainAndAddressRemoved(uint64 chainSelector);
    function test_removePoolFromArray() public {
        vm.prank(Tester);
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));

        vm.prank(Tester);
        vm.expectEmit();
        emit ParentPool_ChainAndAddressRemoved(mockDestinationChainSelector);
        wMaster.removePoolsFromListOfSenders(mockDestinationChainSelector);
    }
}
