// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {ChildPoolDeploy} from "../../../script/ChildPoolDeploy.s.sol";
import {ChildPoolProxyDeploy} from "../../../script/ChildPoolProxyDeploy.s.sol";

import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";


import {USDC} from "../../Mocks/USDC.sol";

contract ConceroChildPoolTest is Test {
    //==== Instantiate Contracts
    ConceroChildPool public childPool;
    
    //==== Instantiate Proxies
    ChildPoolProxy childProxy;
    ITransparentUpgradeableProxy proxyInterfaceChild;

    //==== Instantiate Deploy Script
    ChildPoolDeploy public childDeploy;
    ChildPoolProxyDeploy childProxyDeploy;

    //==== Wrapped contract
    ConceroChildPool wChild;

    //======= Instantiate Mock
    USDC public usdc;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant USDC_INITIAL_BALANCE = 100 * 10**6;

    address proxyOwner = makeAddr("owner");
    address Tester = makeAddr("Tester");
    address Athena = makeAddr("Athena");
    address Orchestrator = makeAddr("Orchestrator");
    address Messenger = makeAddr("Messenger");

    uint64 mockDestinationChainSelector = 5161349165154982;
    address mockLinkTokenAddress = makeAddr("0x01");
    address mockSourceRouter = makeAddr("0x02");
    address mockFunctionsRouter = makeAddr("0x08");

    address mockMasterPoolAddress = makeAddr("0x05");
    address mockConceroContractAddress = makeAddr("0x06");

    bytes32 public constant PROJECT_OWNER = keccak256("PROJECT_OWNER");
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant CONTRACT_MANAGER = keccak256 ("CONTRACT_MANAGER");
    bytes32 public constant WHITE_LIST_MANAGER = keccak256 ("WHITE_LIST_MANAGER");
    bytes32 public constant WHITE_LISTED = keccak256("WHITE_LISTED");

    function setUp() public {
        //======= Deploy Scripts
        childProxyDeploy = new ChildPoolProxyDeploy();
        childDeploy = new ChildPoolDeploy();

        //======= Deploy Mock
        usdc = new USDC("USDC", "USDC", Tester, USDC_INITIAL_BALANCE);

        //======= Deploy proxies
        childProxy = childProxyDeploy.run(address(childDeploy), proxyOwner, "");

        //======= Wraps on the interface to update later 
        proxyInterfaceChild = ITransparentUpgradeableProxy(address(childProxy));

        //======= Deploy MasterPool
        childPool = childDeploy.run(
            Orchestrator,
            address(childProxy),
            mockLinkTokenAddress,
            mockSourceRouter,
            address(usdc),
            Tester
        );

        vm.prank(proxyOwner);
        proxyInterfaceChild.upgradeToAndCall(address(childPool), "");

        wChild = ConceroChildPool(payable(address(childProxy)));
    }

    ///////////////////////////////////////////////////////////////
    ////////////////////////Admin Functions////////////////////////
    ///////////////////////////////////////////////////////////////

    //setConceroContractSender
    event ConceroChildPool_ConceroSendersUpdated(uint64 chainSelector, address contractAddress, uint256 isAllowed);
    function test_setConceroContractSender() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroChildPool_ConceroSendersUpdated(mockDestinationChainSelector, mockMasterPoolAddress, 1);
        wChild.setConceroContractSender(mockDestinationChainSelector, mockMasterPoolAddress, 1);

        assertEq(wChild.s_contractsToReceiveFrom(mockDestinationChainSelector, mockMasterPoolAddress), 1);
    }

    error ConceroChildPool_NotContractOwner();
    error ConceroChildPool_InvalidAddress();
    function test_setConceroContractSenderRevert() public {
        
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_NotContractOwner.selector));
        wChild.setConceroContractSender(mockDestinationChainSelector, mockMasterPoolAddress, 1);

        
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_InvalidAddress.selector));
        wChild.setConceroContractSender(mockDestinationChainSelector, address(0), 1);
    }

    //orchestratorLoan
    event ConceroChildPool_LoanTaken(address receiver, uint256 amount);
    function test_childOrchestratorLoan() public {
        vm.prank(Tester);
        usdc.transfer(address(wChild), USDC_INITIAL_BALANCE);

        assertEq(usdc.balanceOf(address(wChild)), USDC_INITIAL_BALANCE);

        vm.prank(Orchestrator);
        vm.expectEmit();
        emit ConceroChildPool_LoanTaken(address(Orchestrator), USDC_INITIAL_BALANCE);
        wChild.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(Orchestrator));

        assertEq(usdc.balanceOf(Orchestrator), USDC_INITIAL_BALANCE);
    }

    error ConceroChildPool_CallerIsNotTheProxy(address);
    error ConceroChildPool_CallerIsNotConcero(address);
    error ConceroChildPool_InsufficientBalance();
    function test_childOrchestratorLoanRevert() public {
        vm.prank(Tester);
        usdc.transfer(address(wChild), USDC_INITIAL_BALANCE);

        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_CallerIsNotTheProxy.selector, address(childPool)));
        childPool.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(Orchestrator));

        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_CallerIsNotConcero.selector, address(this)));
        wChild.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(Orchestrator));

        vm.prank(Orchestrator);
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_InsufficientBalance.selector));
        wChild.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE + 1, address(Orchestrator));
        
        vm.prank(Orchestrator);
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_InvalidAddress.selector));
        wChild.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));
    }

    function test_notProxyRevert() public {
        vm.prank(Orchestrator);
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_CallerIsNotTheProxy.selector, address(childPool)));
        childPool.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(Orchestrator));
    }
    
    error ConceroChildPool_NotMessenger(address);
    function test_onlyMessengerCanCall() public {
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_NotMessenger.selector, address(this)));
        wChild.ccipSendToPool(mockDestinationChainSelector, Tester, 1000*10**6);
    }
}
