// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Concero} from "../src/Concero.sol";
import {ConceroPool} from "../src/ConceroPool.sol";
import {ConceroPoolDeploy} from "../script/ConceroPoolDeploy.s.sol";

import {USDC} from "./Mocks/USDC.sol";
import {CCIPLocalSimulator, IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract ConceroIntegrationPoolTest is Test {

    Concero public concero;
    ConceroPool public pool;
    ConceroPool public poolReceiver;
    ConceroPoolDeploy public deployPool;
    CCIPLocalSimulator public ccipLocalSimulator;
    USDC public mUSDC;

    uint256 private constant INITIAL_BALANCE = 10 ether;
    uint256 private constant BIGGER_INITIAL_BALANCE = 1000 ether;
    uint256 private constant THRESHOLD = 10;
    uint64 private destinationChainSelector;
    BurnMintERC677Helper private cccipToken;
    address source_Router;

    address Barba = makeAddr("Barba");
    address Puka = makeAddr("Puka");
    address Athena = makeAddr("Athena");
    address Exploiter = makeAddr("Exploiter");
    address Messenger = makeAddr("Messenger");
    address UserReceiver = makeAddr("Receiver");

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
        source_Router = address(sourceRouter);

        mUSDC = new USDC("USDC", "mUSDC", Barba, INITIAL_BALANCE);

        deployPool = new ConceroPoolDeploy();
        pool = deployPool.run(address(linkToken), address(sourceRouter));
        poolReceiver = deployPool.run(address(linkToken), address(destinationRouter));
        
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        pool.transferOwnership(Barba);
        
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        poolReceiver.transferOwnership(Barba);

        vm.deal(Barba, INITIAL_BALANCE);
        vm.deal(Puka, INITIAL_BALANCE);
        vm.deal(Athena, INITIAL_BALANCE);

        mUSDC.mint(Puka, INITIAL_BALANCE);
        mUSDC.mint(Athena, INITIAL_BALANCE);

        ccipBnM.drip(address(poolReceiver));
        ccipBnM.drip(address(pool));
        ccipBnM.drip(Puka);

        ccipLocalSimulator.requestLinkFromFaucet(address(poolReceiver), INITIAL_BALANCE);
    }
    
    modifier setApprovals(){
        vm.startPrank(Barba);
        concero.setConceroOrchestrator(Orchestrator);
        concero.setSupportedToken(address(0), 1);
        concero.setSupportedToken(address(mUSDC), 1);
        concero.setSupportedToken(address(cccipToken), 1);

        concero.setApprovedSender(address(0), Puka);
        concero.setApprovedSender(address(mUSDC), Puka);
        concero.setApprovedSender(address(cccipToken), Puka);
        vm.stopPrank();
        _;
    }

    function test_tokenDecimals() public {
        assertEq(mUSDC.decimals(), 6);
    }
}