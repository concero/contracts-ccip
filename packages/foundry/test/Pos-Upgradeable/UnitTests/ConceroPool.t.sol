// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {ConceroPoolDeploy} from "../../../script/ConceroPoolDeploy.s.sol";
import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";
import {MasterPoolProxyDeploy} from "../../../script/MasterPoolProxyDeploy.s.sol";

import {ConceroPool} from "contracts/ConceroPool.sol";
import {LPToken} from "contracts/LPToken.sol";

import {MasterPoolProxy} from "contracts/Proxy/MasterPoolProxy.sol";


import {USDC} from "../../Mocks/USDC.sol";

contract ConceroPoolTest is Test {
    //==== Instantiate Contracts
    ConceroPool public masterPool;
    LPToken public lp;
    
    //==== Instantiate Proxies
    MasterPoolProxy masterProxy;
    ITransparentUpgradeableProxy proxyInterfaceMaster;

    //==== Instantiate Deploy Script
    ConceroPoolDeploy public masterDeploy;
    LPTokenDeploy public lpDeploy;
    MasterPoolProxyDeploy masterProxyDeploy;

    //==== Wrapped contract
    ConceroPool wMaster;

    //======= Instantiate Mock
    USDC public usdc;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant USDC_INITIAL_BALANCE = 10 * 10**6;

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
        masterProxyDeploy = new MasterPoolProxyDeploy();
        masterDeploy = new ConceroPoolDeploy();
        lpDeploy = new LPTokenDeploy();

        //======= Deploy Mock
        usdc = new USDC("USDC", "USDC", Tester, USDC_INITIAL_BALANCE);

        //======= Deploy proxies
        masterProxy = masterProxyDeploy.run(address(lpDeploy), proxyOwner, Tester, "");

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

        wMaster = ConceroPool(payable(address(masterProxy)));
    }

    ///////////////////////////////////////////////////////////////
    ////////////////////////Admin Functions////////////////////////
    ///////////////////////////////////////////////////////////////
    ///setConceroContractSender///
    event MasterStorage_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256);
    function test_setConceroPool() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit MasterStorage_ConceroSendersUpdated(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
        wMaster.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);

        assertEq(wMaster.s_poolToReceiveFrom(mockDestinationChainSelector, address(mockChildPoolAddress)), 1);
    }

    error MasterStorage_NotContractOwner();
    function test_revertSetConceroPool() public {
        vm.expectRevert(abi.encodeWithSelector(MasterStorage_NotContractOwner.selector));
        wMaster.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
    }

    //setConceroPoolReceiver///
    event MasterStorage_PoolReceiverUpdated(uint64 chainSelector, address contractAddress);
    function test_setConceroPoolReceiver() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit MasterStorage_PoolReceiverUpdated(mockDestinationChainSelector, address(mockChildPoolAddress));
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));

        assertEq(wMaster.s_poolToSendTo(mockDestinationChainSelector), address(mockChildPoolAddress));
    }

    function test_revertSetConceroPoolReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(MasterStorage_NotContractOwner.selector));
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));
    }

    ///orchestratorLoan///
    error ConceroPool_ItsNotOrchestrator(address);
    error ConceroPool_InsufficientBalance();
    error ConceroPool_InvalidAddress();
    function test_orchestratorLoanRevert() external {

        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ItsNotOrchestrator.selector, address(this)));
        wMaster.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));

        vm.startPrank(Orchestrator);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InvalidAddress.selector));
        wMaster.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));

        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InsufficientBalance.selector));
        wMaster.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));

        vm.stopPrank();
    }

    error ConceroPool_AmountBelowMinimum(uint256 amount);
    error ConceroPool_ThereIsNoPoolToDistribute();
    error ConceroPool_MaxCapReached(uint256);
    event MasterStorage_MasterPoolCapUpdated(uint256);
    function test_depositLiquidityRevert() public {
        uint256 amountToDeposit = 1*10**5;
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_AmountBelowMinimum.selector, 100*10**6));
        wMaster.depositLiquidity(amountToDeposit);

        uint256 allowedAmountToDeposit = 100*10**6;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_MaxCapReached.selector, 0));
        wMaster.depositLiquidity(allowedAmountToDeposit);

        vm.prank(Tester);
        vm.expectEmit();
        emit MasterStorage_MasterPoolCapUpdated(100*10**6);
        wMaster.setPoolCap(100*10**6);
        
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ThereIsNoPoolToDistribute.selector));
        wMaster.depositLiquidity(allowedAmountToDeposit);
    }

    event MasterStorage_ChainAndAddressRemoved(uint64 chainSelector);
    function test_removePoolFromArray() public {
        vm.prank(Tester);
        wMaster.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));

        vm.prank(Tester);
        vm.expectEmit();
        emit MasterStorage_ChainAndAddressRemoved(mockDestinationChainSelector);
        wMaster.removePoolsFromListOfSenders(mockDestinationChainSelector);
    }
}
