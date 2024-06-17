// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ConceroPool} from "contracts/ConceroPool.sol";
import {LPToken} from "contracts/LPToken.sol";

import {ConceroPoolDeploy} from "../../../script/ConceroPoolDeploy.s.sol";
import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";

import {USDC} from "../../Mocks/USDC.sol";

contract ConceroPoolTest is Test {
    ConceroPool public pool;
    LPToken public lp;

    ConceroPoolDeploy public deploy;
    LPTokenDeploy public lpDeploy;

    USDC public usdc;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant USDC_INITIAL_BALANCE = 10 * 10**6;

    address Tester = makeAddr("Tester");
    address Puka = makeAddr("Puka");
    address Athena = makeAddr("Athena");
    address Exploiter = makeAddr("Exploiter");
    address Orchestrator = makeAddr("Orchestrator");
    address Messenger = makeAddr("Messenger");
    address UserReceiver = makeAddr("Receiver");

    uint64 mockDestinationChainSelector = 5161349165154982;
    address mockLinkTokenAddress = makeAddr("0x01");
    address mockSourceRouter = makeAddr("0x02");
    address mockLPTokenAddress = makeAddr("0x03");
    address mockAutomationAddress = makeAddr("0x04");

    address mockChildPoolAddress = makeAddr("0x05");
    address mockConceroContractAddress = makeAddr("0x06");

    bytes32 public constant PROJECT_OWNER = keccak256("PROJECT_OWNER");
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public constant CONTRACT_MANAGER = keccak256 ("CONTRACT_MANAGER");
    bytes32 public constant WHITE_LIST_MANAGER = keccak256 ("WHITE_LIST_MANAGER");
    bytes32 public constant WHITE_LISTED = keccak256("WHITE_LISTED");

    function setUp() public {
        usdc = new USDC("USDC", "USDC", Tester, USDC_INITIAL_BALANCE);
        deploy = new ConceroPoolDeploy();
        lpDeploy = new LPTokenDeploy();

        lp = lpDeploy.run(Tester, address(0));
        pool = deploy.run(mockLinkTokenAddress, mockSourceRouter, address(usdc), address(lp), mockAutomationAddress, Tester);

        vm.prank(Tester);
        lp.grantRole(keccak256("CONTRACT_MANAGER"), Puka);
        vm.prank(Tester);
        lp.grantRole(keccak256("MINTER_ROLE"), address(pool));

        vm.deal(Tester, INITIAL_BALANCE);
    }

    ///////////////////////////////////////////////////////////////
    ////////////////////////Admin Functions////////////////////////
    ///////////////////////////////////////////////////////////////
    ///setConceroContractSender///
    event ConceroPool_ConceroSendersUpdated(uint64 chainSelector, address conceroContract, uint256);
    function test_setConceroPool() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroPool_ConceroSendersUpdated(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
        pool.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);

        assertEq(pool.s_contractsToReceiveFrom(mockDestinationChainSelector, address(mockChildPoolAddress)), 1);
    }

    error NotContractOwner();
    function test_revertSetConceroPool() public {
        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector));
        pool.setConceroContractSender(mockDestinationChainSelector, address(mockChildPoolAddress), 1);
    }

    //setConceroPoolReceiver///
    event ConceroPool_PoolReceiverUpdated(uint64 chainSelector, address contractAddress);
    function test_setConceroPoolReceiver() public {
        vm.prank(Tester);
        vm.expectEmit();
        emit ConceroPool_PoolReceiverUpdated(mockDestinationChainSelector, address(mockChildPoolAddress));
        pool.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));

        assertEq(pool.s_poolToSendTo(mockDestinationChainSelector), address(mockChildPoolAddress));
    }

    function test_revertSetConceroPoolReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector));
        pool.setPoolsToSend(mockDestinationChainSelector, address(mockChildPoolAddress));
    }

    ///setConceroContract///
    event ConceroPool_ConceroContractUpdated(address conceroContract);
    function test_setConceroContract() public {
        vm.startPrank(Tester);
        vm.expectEmit();
        emit ConceroPool_ConceroContractUpdated(mockConceroContractAddress);
        pool.setConceroContract(mockConceroContractAddress);
    }

    function test_setConceroContractRevert() public {
        vm.expectRevert(abi.encodeWithSelector(NotContractOwner.selector));
        pool.setConceroContract(mockConceroContractAddress);
    }

    ///orchestratorLoan///
    error ConceroPool_ItsNotConcero(address);
    error ConceroPool_InsufficientBalance();
    error ConceroPool_InvalidAddress();
    function test_orchestratorLoanRevert() external {
        //====== Update Concero Address to test the revert
        vm.startPrank(Tester);
        pool.setConceroContract(mockConceroContractAddress);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ItsNotConcero.selector, address(this)));
        pool.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));

        vm.startPrank(mockConceroContractAddress);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InvalidAddress.selector));
        pool.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(0));

        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InsufficientBalance.selector));
        pool.orchestratorLoan(address(usdc), USDC_INITIAL_BALANCE, address(this));

        vm.stopPrank();
    }

    error ConceroPool_EmptyDepositedIsNotAllowed(uint256 amount);
    error ConceroPool_ThereIsNoPoolToDistribute();
    function test_depositLiquidityRevert() public {
        uint256 amountToDeposit = 1*10**5;
        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_EmptyDepositedIsNotAllowed.selector, amountToDeposit));
        pool.depositLiquidity(amountToDeposit);

        uint256 allowedAmountToDeposit = 1*10**6;

        vm.prank(Tester);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ThereIsNoPoolToDistribute.selector));
        pool.depositLiquidity(allowedAmountToDeposit);
    }
}
