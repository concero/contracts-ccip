// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.19;

// import {Test, console2} from "forge-std/Test.sol";
// import {ConceroPool} from "../../src/ConceroPool.sol";
// import {ConceroPoolDeploy} from "../../script/ConceroPoolDeploy.s.sol";

// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
// import {CCIPLocalSimulator, IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

// contract ConceroPoolFuzzing is Test {
//     ConceroPool public concero;
//     ConceroPoolDeploy public deploy;
//     CCIPLocalSimulator public ccipLocalSimulator;
//     ERC20Mock public mockUSDC;
//     ERC20Mock public mockUSDT;
//     ERC20Mock public fakeCoin;

//     uint256 private constant INITIAL_BALANCE = 10 ether;
//     uint256 private constant APPROVED = 1;

//     address Tester = makeAddr("Tester");
//     address Puka = makeAddr("Puka");
//     address Athena = makeAddr("Athena");
//     address Exploiter = makeAddr("Exploiter");

//     function setUp() public {
//         ccipLocalSimulator = new CCIPLocalSimulator();

//         (
//             uint64 chainSelector,
//             IRouterClient sourceRouter,
//             IRouterClient destinationRouter,
//             WETH9 wrappedNative,
//             LinkToken linkToken,
//             BurnMintERC677Helper ccipBnM,
//             BurnMintERC677Helper ccipLnM
//         ) = ccipLocalSimulator.configuration();

//         mockUSDC = new ERC20Mock("mockUSDC", "mUSDC", Tester, INITIAL_BALANCE);
//         mockUSDT = new ERC20Mock("mockUSDT", "mUSDT", Tester, INITIAL_BALANCE);
//         fakeCoin = new ERC20Mock("fakeCoin", "fCOIN", Tester, INITIAL_BALANCE);

//         deploy = new ConceroPoolDeploy();
//         concero = deploy.run(address(linkToken), address(destinationRouter));

//         vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
//         concero.transferOwnership(Tester);

//         vm.deal(Tester, INITIAL_BALANCE);
//         vm.deal(Puka, INITIAL_BALANCE);
//         vm.deal(Athena, INITIAL_BALANCE);

//         mockUSDC.mint(Puka, INITIAL_BALANCE);
//         mockUSDT.mint(Puka, INITIAL_BALANCE);
//         mockUSDC.mint(Athena, INITIAL_BALANCE);
//         mockUSDT.mint(Athena, INITIAL_BALANCE);
//     }

//     function auth(address _token, address _caller) public{
//         vm.assume(_caller != address(0) && _caller != address(concero));
//         vm.startPrank(Tester);
//         concero.setSupportedToken(_token, APPROVED);
//         concero.setApprovedSender(_token, _caller);
//         vm.stopPrank();
//     }

//     ///setSupportedToken///
//     event ConceroPool_TokenSupportedUpdated(address token, uint256 isSupported);
//     error OwnableUnauthorizedAccount(address _caller);
//     function test_supportedToken(address _token, uint256 _isAllowed) public {
//         vm.prank(Tester);
//         vm.expectEmit();
//         emit ConceroPool_TokenSupportedUpdated(_token, _isAllowed);
//         concero.setSupportedToken(_token, _isAllowed);

//         assertEq(concero.s_isTokenSupported(_token), _isAllowed);

//         vm.expectRevert("Ownable: caller is not the owner");
//         concero.setSupportedToken(_token, _isAllowed);
//     }

//     ///set approvedSender///
//     error ConceroPool_TokenNotSupported();
//     event ConceroPool_ApprovedSenderUpdated(address token, address indexed newSender);
//     function test_approvedSender(address _token, address _approvedSender, uint256 _isAllowed) public {
//         vm.prank(Tester);
//         vm.expectEmit();
//         emit ConceroPool_TokenSupportedUpdated(_token, _isAllowed);
//         concero.setSupportedToken(_token, _isAllowed);

//         vm.expectRevert("Ownable: caller is not the owner");
//         concero.setApprovedSender(_token, _approvedSender);

//         if(_isAllowed == APPROVED){
//             vm.prank(Tester);
//             vm.expectEmit();
//             emit ConceroPool_ApprovedSenderUpdated(_token, _approvedSender);
//             concero.setApprovedSender(_token, _approvedSender);

//             address allowedSender = concero.s_approvedSenders(_token);

//             assertEq(allowedSender, _approvedSender);
//         } else {
//             vm.prank(Tester);
//             vm.expectRevert(abi.encodeWithSelector(ConceroPool_TokenNotSupported.selector));
//             concero.setApprovedSender(_token, _approvedSender);
//         }
//     }

//     ///depositEther///
//     event ConceroPool_Deposited(address indexed token, address indexed from, uint256 amount);
//     function test_ether(address _caller, uint256 _amount) public{

//         vm.assume(_caller != address(0) && _caller != address(concero));

//         vm.startPrank(Tester);
//         concero.setSupportedToken(address(0), APPROVED);
//         concero.setApprovedSender(address(0), _caller);
//         vm.stopPrank();

//         vm.deal(_caller, _amount);

//         uint256 conceroBalanceBefore = address(concero).balance;
//         uint256 callerBalanceBefore = _caller.balance;

//         vm.prank(_caller);
//         vm.expectEmit();
//         emit ConceroPool_Deposited(address(0), _caller, _amount);
//         concero.depositEther{value: _amount}();

//         uint256 conceroBalanceAfter = address(concero).balance;
//         uint256 callerBalanceAfter = _caller.balance;

//         assertEq(conceroBalanceAfter, conceroBalanceBefore + _amount);
//         assertEq(callerBalanceAfter, callerBalanceBefore - _amount);

//         assertEq(concero.s_userBalances(address(0), _caller), _amount);
//     }

//     ///withdrawEther///
//     ///reverting with VmCalls
//     event ConceroPool_Withdrawn(address indexed token, address indexed to, uint256 amount);
//     // function test_etherWithdraw(address payable _caller, uint256 _amount) public {

//     //     vm.assume(_caller != address(0) && _caller != address(concero));


//     //     vm.startPrank(Tester);
//     //     concero.setSupportedToken(address(0), APPROVED);
//     //     concero.setApprovedSender(address(0), _caller);
//     //     vm.stopPrank();

//     //     vm.deal(_caller, _amount);

//     //     vm.prank(_caller);
//     //     vm.expectEmit();
//     //     emit ConceroPool_Deposited(address(0), _caller, _amount );
//     //     concero.depositEther{value: _amount }();

//     //     //======================================

//     //     vm.prank(payable(_caller));
//     //     vm.expectEmit();
//     //     emit ConceroPool_Withdrawn(address(0), _caller, _amount );
//     //     concero.withdrawEther(_amount );
//     // }

//     //depositToken
//     function test_tokenDeposit(address _caller, uint256 _amount) public {
//         vm.assume(_amount < type(uint128).max);
//         vm.assume(_caller != address(0) && _caller != address(concero));
//         vm.startPrank(Tester);
//         concero.setSupportedToken(address(mockUSDC), APPROVED);
//         concero.setApprovedSender(address(mockUSDC), _caller);
//         vm.stopPrank();

//         mockUSDC.mint(_caller, _amount);
//         vm.prank(_caller);
//         mockUSDC.approve(address(concero), _amount);

//         uint256 callerBalanceBeforeTransfer = mockUSDC.balanceOf(_caller);

//         vm.prank(_caller);
//         vm.expectEmit();
//         emit ConceroPool_Deposited(address(mockUSDC), _caller, _amount);
//         concero.depositToken(address(mockUSDC), _amount);

//         assertEq(mockUSDC.balanceOf(address(concero)), _amount);
//         assertEq(mockUSDC.balanceOf(_caller), callerBalanceBeforeTransfer - _amount);
//     }

//     // function test_withdrawTokens(address _caller, uint256 _amount) public {
//     //     vm.assume(_amount < type(uint128).max);
//     //     vm.assume(_caller != address(0) && _caller != address(concero));

//     //     vm.startPrank(Tester);
//     //     concero.setSupportedToken(address(mockUSDC), APPROVED);
//     //     concero.setApprovedSender(address(mockUSDC), _caller);
//     //     vm.stopPrank();

//     //     mockUSDC.mint(_caller, _amount);
//     //     vm.prank(_caller);
//     //     mockUSDC.approve(address(concero), _amount);

//     //     vm.prank(_caller);
//     //     concero.depositToken(address(mockUSDC), _amount);

//     //     //===================

//     //     uint256 callerBalanceBeforeWithdraw = mockUSDC.balanceOf(_caller);
//     //     uint256 conceroBalanceTrackBeforeWithdraw = concero.s_userBalances(address(mockUSDC), _caller);

//     //     vm.prank(_caller);
//     //     vm.expectEmit();
//     //     emit ConceroPool_Withdrawn(address(mockUSDC), _caller, _amount);
//     //     concero.withdrawToken(address(mockUSDC));

//     //     uint256 callerBalanceAfterWithdraw = mockUSDC.balanceOf(_caller);
//     //     uint256 conceroBalanceTrackAfterWithdraw = concero.s_userBalances(address(mockUSDC), _caller);

//     //     assertEq(conceroBalanceTrackAfterWithdraw, conceroBalanceTrackBeforeWithdraw - _amount);
//     //     assertEq(callerBalanceAfterWithdraw, callerBalanceBeforeWithdraw + _amount);
//     // }
// }
