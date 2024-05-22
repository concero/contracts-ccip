// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ConceroPool} from "../src/ConceroPool.sol";
import {ConceroPoolDeploy} from "../script/ConceroPoolDeploy.s.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {CCIPLocalSimulator, IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract ConceroPoolTest is Test {
    ConceroPool public concero;
    ConceroPool public conceroReceiver;
    ConceroPoolDeploy public deploy;
    CCIPLocalSimulator public ccipLocalSimulator;
    ERC20Mock public mockUSDC;
    ERC20Mock public mockUSDT;
    ERC20Mock public fakeCoin;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant BIGGER_INITIAL_BALANCE = 1000 ether;
    uint256 private constant THRESHOLD = 10;
    uint64 private destinationChainSelector;
    BurnMintERC677Helper private cccipToken;
    address source;

    address Barba = makeAddr("Barba");
    address Puka = makeAddr("Puka");
    address Athena = makeAddr("Athena");
    address Exploiter = makeAddr("Exploiter");
    address Orchestrator = makeAddr("Orchestrator");
    address Messenger = makeAddr("Messenger");

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();

        (
            uint64 chainSelector,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            // WETH9 wrappedNative
            ,
            LinkToken linkToken,
            BurnMintERC677Helper ccipBnM,
            // BurnMintERC677Helper ccipLnM
        ) = ccipLocalSimulator.configuration();

        destinationChainSelector = chainSelector;
        cccipToken = (ccipBnM);
        source = address(sourceRouter);

        mockUSDC = new ERC20Mock("mockUSDC", "mUSDC", Barba, INITIAL_BALANCE);
        mockUSDT = new ERC20Mock("mockUSDT", "mUSDT", Barba, INITIAL_BALANCE);
        fakeCoin = new ERC20Mock("fakeCoin", "fCOIN", Barba, INITIAL_BALANCE);

        deploy = new ConceroPoolDeploy();
        concero = deploy.run(address(linkToken), address(sourceRouter));
        conceroReceiver = deploy.run(address(linkToken), address(destinationRouter));
        
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        concero.transferOwnership(Barba);
        
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        conceroReceiver.transferOwnership(Barba);

        vm.deal(Barba, INITIAL_BALANCE);
        vm.deal(Puka, INITIAL_BALANCE);
        vm.deal(Athena, INITIAL_BALANCE);

        mockUSDC.mint(Puka, INITIAL_BALANCE);
        mockUSDT.mint(Puka, INITIAL_BALANCE);
        mockUSDC.mint(Athena, INITIAL_BALANCE);
        mockUSDT.mint(Athena, INITIAL_BALANCE);

        ccipBnM.drip(address(conceroReceiver));
        ccipBnM.drip(address(concero));

        ccipLocalSimulator.requestLinkFromFaucet(address(conceroReceiver), INITIAL_BALANCE);
    }

    
    modifier setApprovals(){
        vm.startPrank(Barba);
        concero.setConceroOrchestrator(Orchestrator);
        concero.setSupportedToken(address(0), 1);
        concero.setSupportedToken(address(mockUSDC), 1);
        concero.setSupportedToken(address(mockUSDT), 1);
        concero.setSupportedToken(address(cccipToken), 1);

        concero.setApprovedSender(address(0), Puka);
        concero.setApprovedSender(address(mockUSDC), Puka);
        concero.setApprovedSender(address(mockUSDT), Puka);
        concero.setApprovedSender(address(cccipToken), Puka);
        vm.stopPrank();
        _;
    }

    ///////////////////////////////////////////////////////////////
    ////////////////////////Admin Functions////////////////////////
    ///////////////////////////////////////////////////////////////

    ///setConceroOrchestrator///
    event ConceroPool_OrchestratorUpdated(address previousOrchestrator, address orchestrator);
    function test_setConceroOrchestrator() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit ConceroPool_OrchestratorUpdated(address(0), Orchestrator);
        concero.setConceroOrchestrator(Orchestrator);

        assertEq(concero.s_conceroOrchestrator(), Orchestrator);
    }

    function test_revertSetConceroOrchestrator() public {
        vm.expectRevert("Ownable: caller is not the owner");
        concero.setConceroOrchestrator(Orchestrator);
    }

    ///setMessenger///
    event ConceroPool_MessengerAddressUpdated(address previousMessenger, address messengerAddress);
    function test_setMessenger() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit ConceroPool_MessengerAddressUpdated(address(0), Messenger);
        concero.setMessenger(Messenger);

        assertEq(concero.s_messengerAddress(), Messenger);
    }

    function test_revertSetMessenger() public {
        vm.expectRevert("Ownable: caller is not the owner");
        concero.setMessenger(Orchestrator);
    }

    ///setConceroPool///
    event ConceroPool_ConceroContractUpdated(uint64 chainSelector, address conceroContract);
    function test_setConceroPool() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit ConceroPool_ConceroContractUpdated(destinationChainSelector, address(conceroReceiver));
        concero.setConceroPool(destinationChainSelector, address(conceroReceiver));

        assertEq(concero.s_allowedPool(destinationChainSelector), address(conceroReceiver));
    }

    function test_revertSetConceroPool() public {
        vm.expectRevert("Ownable: caller is not the owner");
        concero.setConceroPool(destinationChainSelector, address(conceroReceiver));
    }

    ///setSupportedToken///
    event ConceroPool_TokenSupportedUpdated(address token, uint256 isSupported);
    function test_setSupportedToken() public {
        vm.prank(Barba);
        vm.expectEmit();
        emit ConceroPool_TokenSupportedUpdated(address(mockUSDC), 1);
        concero.setSupportedToken(address(mockUSDC), 1);

        assertEq(concero.s_isTokenSupported(address(mockUSDC)), 1);
    }

    function test_revertsSetSupportedToken() public {
        vm.expectRevert("Ownable: caller is not the owner");
        concero.setSupportedToken(address(mockUSDC), 1);
    }

    ///setApprovedSender///
    event ConceroPool_ApprovedSenderUpdated(address token, address indexed newSender);
    function test_setApprovedSender() public {
        vm.startPrank(Barba);
        concero.setSupportedToken(address(mockUSDC), 1);

        vm.expectEmit();
        emit ConceroPool_ApprovedSenderUpdated(address(mockUSDC), Puka);
        concero.setApprovedSender(address(mockUSDC), Puka);

        assertEq(concero.s_approvedSenders(address(mockUSDC)), Puka);
    }

    error OwnableUnauthorizedAccount(address _caller);
    error ConceroPool_TokenNotSupported();
    function test_revertsSetApproveSender() public {
        vm.prank(Exploiter);
        vm.expectRevert("Ownable: caller is not the owner");
        concero.setApprovedSender(address(mockUSDC), Puka);

        vm.prank(Barba);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_TokenNotSupported.selector));
        concero.setApprovedSender(address(fakeCoin), Exploiter);
    }

    ///depositEther///
    function test_depositEther() public setApprovals{
        uint256 conceroBalanceBefore = address(concero).balance;
        uint256 pukaBalanceBefore = Puka.balance;

        vm.prank(Puka);
        concero.depositEther{value: 1 ether}();

        uint256 pukaBalanceAfter = Puka.balance;
        uint256 conceroBalanceAfter = address(concero).balance;

        assertEq(conceroBalanceAfter, conceroBalanceBefore + 1 ether);
        assertEq(conceroBalanceAfter, 1 ether);
        assertEq(pukaBalanceAfter, pukaBalanceBefore - 1 ether);

        assertEq(concero.s_userBalances(address(0), Puka), 1 ether);
    }

    error ConceroPool_Unauthorized();
    function test_revertsDepositEther() public setApprovals{
        vm.prank(Barba);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_Unauthorized.selector));
        concero.depositEther{value: 1 ether}();

        assertEq(address(concero).balance, 0);
        assertEq(concero.s_userBalances(address(0), Barba), 0);
    }

    ///depositToken///
    event ConceroPool_Deposited(address indexed token, address indexed from, uint256 amount);
    function test_depositTokenUSDC() public setApprovals{
        vm.startPrank(Puka);
        mockUSDC.approve(address(concero), 6 ether);
        mockUSDT.approve(address(concero), 6 ether);

        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDC), Puka, 6 ether);
        concero.depositToken(address(mockUSDC), 6 ether);

        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDT), Puka, 6 ether);
        concero.depositToken(address(mockUSDT), 6 ether);
        vm.stopPrank();

        //=============================================================

        assertEq(mockUSDC.balanceOf(address(concero)), 6 ether);
        assertEq(mockUSDT.balanceOf(address(concero)), 6 ether);

        //=============================================================

        assertEq(concero.s_userBalances(address(mockUSDC), Puka), 6 ether);
        assertEq(concero.s_userBalances(address(mockUSDT), Puka), 6 ether);

        assertEq(mockUSDC.balanceOf(Puka), 4 ether);
        assertEq(mockUSDT.balanceOf(Puka), 4 ether);

        //=============================================================

        assertEq(mockUSDC.balanceOf(address(concero)), 6 ether);
        assertEq(mockUSDT.balanceOf(address(concero)), 6 ether);
    }

    function test_revertDepositToken() public setApprovals{
        vm.prank(Exploiter);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_Unauthorized.selector));
        concero.depositToken(address(mockUSDC), 6 ether);
        vm.stopPrank();
    }

    ///withdrawEther///
    event ConceroPool_WithdrawRequest(address caller, address token, uint256 condition, uint256 amount);
    event ConceroPool_Withdrawn(address to, address token, uint256 amount);
    function test_withdrawEtherRequest() public setApprovals{
        uint256 withdrawRequestValue = 4 ether;

        //======== Deposits Ether
        vm.prank(Puka);
        concero.depositEther{value: INITIAL_BALANCE}();

        assertEq(address(concero).balance, INITIAL_BALANCE);
        assertEq(address(concero).balance, concero.s_userBalances(address(0), Puka));

        //======== Create request for ether withdraw
        uint256 threshold = (address(concero).balance - ((address(concero).balance * THRESHOLD) / 100)) + withdrawRequestValue;

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(0), threshold, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);

        assertEq(address(concero).balance, INITIAL_BALANCE);

        //======== Checks if the user balance is still the same
        assertEq(concero.s_userBalances(address(0), Puka), INITIAL_BALANCE);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory request = concero.getRequestInfo(address(0));
        assertEq(request.condition, threshold);
        assertEq(request.amount, withdrawRequestValue);
        assertEq(request.isActiv, true);
        assertEq(request.isFulfilled, false);

        //======== Receives more ether to proceed with the withdraw
        vm.prank(Barba);
        (bool success,) = address(concero).call{value: withdrawRequestValue}("");
        require(success, "Tx Failed");
        assertEq(address(concero).balance, INITIAL_BALANCE + withdrawRequestValue);

        //======== Realize the Withdraw
        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(0), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);

        //======== Checks if the user balance is updated
        assertEq(concero.s_userBalances(address(0), Puka), INITIAL_BALANCE - withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory requestAfter = concero.getRequestInfo(address(0));
        uint256 thresholdAfter = (address(concero).balance - ((address(concero).balance * THRESHOLD) / 100)) + withdrawRequestValue;
        assertEq(requestAfter.condition, thresholdAfter);
        assertEq(requestAfter.amount, withdrawRequestValue);
        assertEq(requestAfter.isActiv, false);
        assertEq(requestAfter.isFulfilled, true);
    }

    function test_withdrawEtherDirectly() public setApprovals{
        uint256 withdrawRequestValue = 0.9 ether;
        //======== Deposits Ether
        vm.prank(Puka);
        concero.depositEther{value: INITIAL_BALANCE}();

        assertEq(address(concero).balance, INITIAL_BALANCE);
        assertEq(address(concero).balance, concero.s_userBalances(address(0), Puka));

        //======== Withdraw Directly by respecting the threshold
        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(0), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);

        assertEq(address(concero).balance, INITIAL_BALANCE - withdrawRequestValue);
        assertEq(Puka.balance, withdrawRequestValue);

        //======== Checks if the user balance is updated
        assertEq(concero.s_userBalances(address(0), Puka), INITIAL_BALANCE - withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory request = concero.getRequestInfo(address(0));
        assertEq(request.condition, 0);
        assertEq(request.amount, 0);
        assertEq(request.isActiv, false);
        assertEq(request.isFulfilled, false);
    }

    error ConceroPool_TransferFailed();
    error ConceroPool_ActivRequestNotFulfilledYet();
    function test_revertWithdrawEther() public setApprovals{
        uint256 withdrawRequestValue = 4 ether;
        //======== Deposits Ether
        vm.prank(Puka);
        concero.depositEther{value: INITIAL_BALANCE}();

        //======== Checks if the value sended is correct accounted

        assertEq(address(concero).balance, INITIAL_BALANCE);
        assertEq(address(concero).balance, concero.s_userBalances(address(0), Puka));

        //======== Test onlyApprovedSender Modifier
        vm.prank(Barba);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_Unauthorized.selector));
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);

        //======== Checks for the amount deposited limit
        vm.prank(Puka);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InsufficientBalance.selector));
        concero.withdrawLiquidityRequest(address(0), INITIAL_BALANCE + withdrawRequestValue);

        //======== Create request for ether withdraw
        uint256 threshold = (address(concero).balance - ((address(concero).balance * THRESHOLD) / 100)) + withdrawRequestValue;

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(0), threshold, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory request = concero.getRequestInfo(address(0));
        assertEq(request.condition, threshold);
        assertEq(request.amount, withdrawRequestValue);
        assertEq(request.isActiv, true);
        assertEq(request.isFulfilled, false);

        //======== Try to withdraw without condition being fulfilled
        vm.prank(Puka);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ActivRequestNotFulfilledYet.selector));
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);
    }

    ///withdrawToken///
    function test_withdrawERC20Request() public setApprovals{
        uint256 withdrawRequestValue = 4 ether;

        //======== Approve the transfer
        vm.startPrank(Puka);
        mockUSDC.approve(address(concero), INITIAL_BALANCE);
        mockUSDT.approve(address(concero), INITIAL_BALANCE);

        //======== Deposits
        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDC), Puka, INITIAL_BALANCE);
        concero.depositToken(address(mockUSDC), INITIAL_BALANCE);

        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDT), Puka, INITIAL_BALANCE);
        concero.depositToken(address(mockUSDT), INITIAL_BALANCE);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE);
        assertEq(mockUSDT.balanceOf(address(concero)), INITIAL_BALANCE);

        //======== Create request for USDC/USDT withdraw
        uint256 thresholdUSDC = (mockUSDC.balanceOf(address(concero)) - ((mockUSDC.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;
        uint256 thresholdUSDT = (mockUSDT.balanceOf(address(concero)) - ((mockUSDT.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(mockUSDC), thresholdUSDC, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(mockUSDT), thresholdUSDT, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDT), withdrawRequestValue);

        //======== Checks if the user balance is still the same
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE);
        assertEq(concero.s_userBalances(address(mockUSDT), Puka), INITIAL_BALANCE);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory requestUSDC = concero.getRequestInfo(address(mockUSDC));
        assertEq(requestUSDC.condition, thresholdUSDC);
        assertEq(requestUSDC.amount, withdrawRequestValue);
        assertEq(requestUSDC.isActiv, true);
        assertEq(requestUSDC.isFulfilled, false);

        ConceroPool.WithdrawRequests memory requestUSDT = concero.getRequestInfo(address(mockUSDT));
        assertEq(requestUSDT.condition, thresholdUSDT);
        assertEq(requestUSDT.amount, withdrawRequestValue);
        assertEq(requestUSDT.isActiv, true);
        assertEq(requestUSDT.isFulfilled, false);

        //======== Receives more USDC/USDT to proceed with the withdraw
        mockUSDC.mint(address(concero), withdrawRequestValue);
        mockUSDT.mint(address(concero), withdrawRequestValue);

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE + withdrawRequestValue);
        assertEq(mockUSDT.balanceOf(address(concero)), INITIAL_BALANCE + withdrawRequestValue);

        //======== Realize the Withdraw
        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(mockUSDC), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(mockUSDT), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDT), withdrawRequestValue);

        //======== Checks if the user balance is updated
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE - withdrawRequestValue);
        assertEq(concero.s_userBalances(address(mockUSDT), Puka), INITIAL_BALANCE - withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory requestAfterUSDC = concero.getRequestInfo(address(mockUSDC));
        uint256 thresholdAfterUSDC = (mockUSDC.balanceOf(address(concero)) - ((mockUSDC.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;
        assertEq(requestAfterUSDC.condition, thresholdAfterUSDC);
        assertEq(requestAfterUSDC.amount, withdrawRequestValue);
        assertEq(requestAfterUSDC.isActiv, false);
        assertEq(requestAfterUSDC.isFulfilled, true);

        ConceroPool.WithdrawRequests memory requestAfterUSDT = concero.getRequestInfo(address(mockUSDT));
        uint256 thresholdAfterUSDT = (mockUSDT.balanceOf(address(concero)) - ((mockUSDT.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;
        assertEq(requestAfterUSDT.condition, thresholdAfterUSDT);
        assertEq(requestAfterUSDT.amount, withdrawRequestValue);
        assertEq(requestAfterUSDT.isActiv, false);
        assertEq(requestAfterUSDT.isFulfilled, true);
    }

    function test_withdrawERC20MultiRequests() public setApprovals{
        uint256 withdrawRequestValue = 4 ether;
        uint256 valueToRebalance = 3 ether;

        //======== Approve the transfer
        vm.startPrank(Puka);
        mockUSDC.approve(address(concero), INITIAL_BALANCE);

        //======== Deposits
        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDC), Puka, INITIAL_BALANCE);
        concero.depositToken(address(mockUSDC), INITIAL_BALANCE);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE);

        //======== Create request for USDC withdraw
        uint256 thresholdUSDC = (mockUSDC.balanceOf(address(concero)) - ((mockUSDC.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(mockUSDC), thresholdUSDC, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        //======== Checks if the user balance is still the same
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory requestUSDC = concero.getRequestInfo(address(mockUSDC));
        assertEq(requestUSDC.condition, thresholdUSDC);
        assertEq(requestUSDC.amount, withdrawRequestValue);
        assertEq(requestUSDC.isActiv, true);
        assertEq(requestUSDC.isFulfilled, false);

        //======== Receives more USDC to proceed with the withdraw
        mockUSDC.mint(address(concero), valueToRebalance);
        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE + valueToRebalance);

        //======== Realize the Withdraw
        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(mockUSDC), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        //======== Checks if the user balance is updated
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE - withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory requestAfterUSDC = concero.getRequestInfo(address(mockUSDC));
        console2.log(requestAfterUSDC.condition);
        assertEq(requestAfterUSDC.condition, thresholdUSDC);
        assertEq(requestAfterUSDC.amount, withdrawRequestValue);
        assertEq(requestAfterUSDC.isActiv, false);
        assertEq(requestAfterUSDC.isFulfilled, true);

        // ===============================================================================================================
        
        //======== Create second request for USDC withdraw
        uint256 secondThresholdUSDC = (mockUSDC.balanceOf(address(concero)) - ((mockUSDC.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(mockUSDC), secondThresholdUSDC, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        //======== Checks if the user balance is still the same
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE - withdrawRequestValue);

        //======== Checks the second request
        ConceroPool.WithdrawRequests memory secondRequestUSDC = concero.getRequestInfo(address(mockUSDC));
        assertEq(secondRequestUSDC.condition, secondThresholdUSDC);
        assertEq(secondRequestUSDC.amount, withdrawRequestValue);
        assertEq(secondRequestUSDC.isActiv, true);
        assertEq(secondRequestUSDC.isFulfilled, false);

        //======== Receives more USDC to proceed with the withdraw
        mockUSDC.mint(address(concero), withdrawRequestValue);

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE + valueToRebalance - withdrawRequestValue + withdrawRequestValue);

        //======== Realize the Withdraw
        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(mockUSDC), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        //======== Checks if the user balance is updated
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE - withdrawRequestValue - withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory secondRequestAfterUSDC = concero.getRequestInfo(address(mockUSDC));
        uint256 thresholdAfterUSDC = (mockUSDC.balanceOf(address(concero)) - ((mockUSDC.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;
        assertEq(secondRequestAfterUSDC.condition, secondThresholdUSDC);
        assertEq(secondRequestAfterUSDC.amount, withdrawRequestValue);
        assertEq(secondRequestAfterUSDC.isActiv, false);
        assertEq(secondRequestAfterUSDC.isFulfilled, true);
    }

    function test_withdrawERC20Directly() public setApprovals{
        uint256 withdrawRequestValue = 0.9 ether;

        //======== Approve the transfer
        vm.startPrank(Puka);
        mockUSDC.approve(address(concero), INITIAL_BALANCE);
        mockUSDT.approve(address(concero), INITIAL_BALANCE);

        //======== Deposits
        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDC), Puka, INITIAL_BALANCE);
        concero.depositToken(address(mockUSDC), INITIAL_BALANCE);

        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDT), Puka, INITIAL_BALANCE);
        concero.depositToken(address(mockUSDT), INITIAL_BALANCE);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE);
        assertEq(mockUSDT.balanceOf(address(concero)), INITIAL_BALANCE);

        //======== Withdraw Directly by respecting the threshold
        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(mockUSDC), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_Withdrawn(Puka, address(mockUSDT), withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDT), withdrawRequestValue);

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE - withdrawRequestValue);
        assertEq(mockUSDT.balanceOf(address(concero)), INITIAL_BALANCE - withdrawRequestValue);
        assertEq(mockUSDC.balanceOf(Puka), withdrawRequestValue);
        assertEq(mockUSDT.balanceOf(Puka), withdrawRequestValue);

        //======== Checks if the user balance is updated
        assertEq(concero.s_userBalances(address(mockUSDC), Puka), INITIAL_BALANCE - withdrawRequestValue);
        assertEq(concero.s_userBalances(address(mockUSDT), Puka), INITIAL_BALANCE - withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory requestUSDC = concero.getRequestInfo(address(mockUSDC));
        assertEq(requestUSDC.condition, 0);
        assertEq(requestUSDC.amount, 0);
        assertEq(requestUSDC.isActiv, false);
        assertEq(requestUSDC.isFulfilled, false);
        
        ConceroPool.WithdrawRequests memory requestUSDT = concero.getRequestInfo(address(mockUSDT));
        assertEq(requestUSDT.condition, 0);
        assertEq(requestUSDT.amount, 0);
        assertEq(requestUSDT.isActiv, false);
        assertEq(requestUSDT.isFulfilled, false);
    }

    error ConceroPool_InsufficientBalance();
    function test_revertWithdrawERC20() public setApprovals{
        uint256 withdrawRequestValue = 4 ether;

        //======== Approve the transfer
        vm.startPrank(Puka);
        mockUSDC.approve(address(concero), INITIAL_BALANCE);

        //======== Deposits
        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDC), Puka, INITIAL_BALANCE);
        concero.depositToken(address(mockUSDC), INITIAL_BALANCE);
        vm.stopPrank();
        //======== Checks if the value sended is correct accounted

        assertEq(mockUSDC.balanceOf(address(concero)), INITIAL_BALANCE);
        assertEq(mockUSDC.balanceOf(address(concero)), concero.s_userBalances(address(mockUSDC), Puka));

        //======== Test onlyApprovedSender Modifier
        vm.prank(Exploiter);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_Unauthorized.selector));
        concero.withdrawLiquidityRequest(address(0), withdrawRequestValue);

        //======== Checks for the amount deposited limit
        vm.prank(Puka);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InsufficientBalance.selector));
        concero.withdrawLiquidityRequest(address(mockUSDC), INITIAL_BALANCE + withdrawRequestValue);

        //======== Create request for ether withdraw
        uint256 threshold = (mockUSDC.balanceOf(address(concero)) - ((mockUSDC.balanceOf(address(concero)) * THRESHOLD) / 100)) + withdrawRequestValue;

        vm.prank(Puka);
        vm.expectEmit();
        emit ConceroPool_WithdrawRequest(Puka, address(mockUSDC), threshold, withdrawRequestValue);
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);

        //======== Checks the request
        ConceroPool.WithdrawRequests memory request = concero.getRequestInfo(address(mockUSDC));
        assertEq(request.condition, threshold);
        assertEq(request.amount, withdrawRequestValue);
        assertEq(request.isActiv, true);
        assertEq(request.isFulfilled, false);

        //======== Try to withdraw without condition being fulfilled
        vm.prank(Puka);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ActivRequestNotFulfilledYet.selector));
        concero.withdrawLiquidityRequest(address(mockUSDC), withdrawRequestValue);
    }

    ///orchestratorLoan///
    function test_depositOrchestratorAndWithdraw() external setApprovals{
        //======= Mock a new address
        address biggerPlayer = makeAddr("Player");

        //======= Set the supported tokens and callers
        vm.startPrank(Barba);
        concero.setSupportedToken(address(0), 1);
        concero.setSupportedToken(address(mockUSDC), 1);
        concero.setApprovedSender(address(0), biggerPlayer);
        concero.setApprovedSender(address(mockUSDC), biggerPlayer);
        vm.stopPrank();

        //======= Measure concero balances before call
        uint256 conceroEtherBalanceBefore = address(concero).balance;
        uint256 conceroERC20BalanceBefore = mockUSDC.balanceOf(address(concero));

        //======= Mints USDC and Give some balance to biggerPlayer
        mockUSDC.mint(biggerPlayer, BIGGER_INITIAL_BALANCE);
        vm.deal(biggerPlayer, BIGGER_INITIAL_BALANCE);

        //======= Checks biggerPlayer balance after emiting tokens
        uint256 biggerPlayerEtherBalanceBefore = biggerPlayer.balance;
        uint256 biggerPlayerERC20BalanceBefore = mockUSDC.balanceOf(biggerPlayer);
        assertEq(biggerPlayerEtherBalanceBefore, BIGGER_INITIAL_BALANCE);
        assertEq(biggerPlayerERC20BalanceBefore, BIGGER_INITIAL_BALANCE);

        //======= Approve the Concero contract to take the deposit
        vm.startPrank(biggerPlayer);
        mockUSDC.approve(address(concero), BIGGER_INITIAL_BALANCE);

        //======= Execute ERC20 deposit biggerPlayer
        vm.expectEmit();
        emit ConceroPool_Deposited(address(mockUSDC), biggerPlayer, BIGGER_INITIAL_BALANCE);
        concero.depositToken(address(mockUSDC), BIGGER_INITIAL_BALANCE);

        //======= Execute Ether deposit for biggerPlayer
        concero.depositEther{value: BIGGER_INITIAL_BALANCE}();
        vm.stopPrank();

        //======= Checks all balances
        uint256 biggerPlayerEtherBalanceAfter = biggerPlayer.balance;
        uint256 biggerPlayerERC20BalanceAfter = mockUSDC.balanceOf(biggerPlayer);
        uint256 conceroEtherBalanceAfter = address(concero).balance;
        uint256 conceroERC20BalanceAfter = mockUSDC.balanceOf(address(concero));

        assertEq(conceroERC20BalanceAfter, conceroERC20BalanceBefore + BIGGER_INITIAL_BALANCE);
        assertEq(conceroERC20BalanceAfter, BIGGER_INITIAL_BALANCE);
        assertEq(conceroEtherBalanceAfter, conceroEtherBalanceBefore + BIGGER_INITIAL_BALANCE);
        assertEq(biggerPlayerEtherBalanceAfter, 0);
        assertEq(biggerPlayerERC20BalanceAfter, 0);
        assertEq(concero.s_userBalances(address(mockUSDC), biggerPlayer), BIGGER_INITIAL_BALANCE);
        assertEq(concero.s_userBalances(address(0), biggerPlayer), BIGGER_INITIAL_BALANCE);

        //======= Mocks a not allowed loan call
        vm.prank(biggerPlayer);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ItsNotAnOrchestrator.selector, biggerPlayer));
        concero.orchestratorLoan(address(mockUSDC), 500 ether);

        //======= Orchestrator takes a ERC20 loan
        vm.startPrank(Orchestrator);
        concero.orchestratorLoan(address(mockUSDC), 500 ether);

        //======= Orchestrator takes a loan that exceeds the amount on the pool
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InsufficientBalance.selector));
        concero.orchestratorLoan(address(mockUSDC), 600 ether);

        //======= Orchestrator takes an Ether loan
        concero.orchestratorLoan(address(0), 500 ether);

        //======= Orchestrator takes an Ether loan that exceeds the amount on the pool
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_InsufficientBalance.selector));
        concero.orchestratorLoan(address(0), 600 ether);
        vm.stopPrank();

        assertEq(mockUSDC.balanceOf(address(concero)), 500 ether);
        assertEq(address(concero).balance, 500 ether);
        assertEq(mockUSDC.balanceOf(Orchestrator), 500 ether);
        assertEq(Orchestrator.balance, 500 ether);
        assertEq(concero.availableBalanceNow(address(mockUSDC)), 500 ether);
        assertEq(concero.availableBalanceNow(address(0)), 500 ether);
    }

    error ConceroPool_ItsNotAnOrchestrator(address caller);
    function test_revertsOrchestratorLoan() public {
        vm.prank(Exploiter);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_ItsNotAnOrchestrator.selector, Exploiter));
        concero.orchestratorLoan(address(0), 10 ether);
    }

    ///ccipSendToPool & ccipReceiver///
    event ConceroPool_RewardWithdrawd(address token, uint256 amount);
    function test_ccipSendToPool() public setApprovals{

        //========= Set the Concero Contracts allowed to receive C-chain messages
        vm.startPrank(Barba);
        concero.setConceroPool(destinationChainSelector, address(conceroReceiver));
        conceroReceiver.setConceroPool(destinationChainSelector, address(concero));

        //========= Mock the messenger address that will be allowed to call the function
        conceroReceiver.setMessenger(Messenger);
        vm.stopPrank();

        //========= Mock LP Fee just to test
        uint256 lpFee = (1 ether * 1) / 10_000; // 0.01
        assertEq(lpFee, 100_000_000_000_000); //100_000_000_000_000

        //========= Call ccipSendToPool function
        vm.startPrank(Messenger);
        conceroReceiver.ccipSendToPool(destinationChainSelector, address(cccipToken), lpFee, "");
        vm.stopPrank();

        //========= Checks if value is delivered as expected
        assertEq(cccipToken.balanceOf(address(conceroReceiver)), 1 ether - lpFee);
        assertEq(cccipToken.balanceOf(address(concero)), 1 ether + lpFee);

        //========= Checks if the value is ignored on the destination as expected
        assertEq(concero.s_userBalances(address(cccipToken), Puka), 0);
    }

    error ConceroPool_DestinationNotAllowed();
    function test_revertCCIPSendToPool() public setApprovals{
        //========= Set the Concero Contracts allowed to receive C-chain messages
        vm.startPrank(Barba);
        concero.setConceroPool(destinationChainSelector, address(conceroReceiver));
        conceroReceiver.setConceroPool(destinationChainSelector, address(concero));

        //========= Mock the messenger address that will be allowed to call the function
        conceroReceiver.setMessenger(Messenger);
        vm.stopPrank();

        //========= Call ccipSendToPool function from an arbitrary not allowed address
        vm.startPrank(Barba);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_Unauthorized.selector));
        conceroReceiver.ccipSendToPool(destinationChainSelector, address(cccipToken), 0, "");
        vm.stopPrank();

        //========= Call ccipSendToPool function passing a not allowed destination
        vm.startPrank(Messenger);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_DestinationNotAllowed.selector));
        conceroReceiver.ccipSendToPool(1651516161, address(cccipToken), 0, "");
        vm.stopPrank();

        //========= Call ccipSendToPool function passing a not allowed destination
        vm.startPrank(Messenger);
        vm.expectRevert(abi.encodeWithSelector(ConceroPool_DestinationNotAllowed.selector));
        conceroReceiver.ccipSendToPool(1651516161, address(0), 0, "");
        vm.stopPrank();

        //========= Mock LP Fee just to test
        uint256 lpFee = (1 ether * 1) / 10_000; // 0.01
        assertEq(lpFee, 100_000_000_000_000); //100_000_000_000_000
        bytes memory data = abi.encode(lpFee);

        //========= Call ccipSendToPool function passing a not allowed destination
        vm.startPrank(Messenger);
        conceroReceiver.ccipSendToPool(destinationChainSelector, address(cccipToken), lpFee, data);
        vm.stopPrank();

        //========= Checks if value is delivered as expected
        assertEq(cccipToken.balanceOf(address(conceroReceiver)), 1 ether - lpFee);
        assertEq(cccipToken.balanceOf(address(concero)), 1 ether + lpFee);

        //========= Checks if the value is correctly stored on the destination
        assertEq(concero.s_userBalances(address(cccipToken), Puka), lpFee);
    }

    //TODO
    //Double check on LP's fees.
}   
