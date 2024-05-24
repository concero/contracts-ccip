// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Concero} from "../src/Concero.sol";
import {ConceroPool} from "../src/ConceroPool.sol";
import {IConceroCommon} from "../src/IConcero.sol";

import {ConceroDeploy} from "../script/ConceroDeploy.s.sol";
import {ConceroPoolDeploy} from "../script/ConceroPoolDeploy.s.sol";
import {HelperConfig} from "../script/HelperConfig.sol";

import {USDC} from "./Mocks/USDC.sol";

import {CCIPLocalSimulator, IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {PriceFeedConsumer} from "./Mocks/PriceFeedConsumer.sol";
import {MockV3Aggregator} from "@starterKit/src/test/mocks/MockV3Aggregator.sol";

contract ConceroIntegrationPoolTest is Test {
    //Instantiate Contracts
    Concero public concero;
    ConceroPool public pool;
    ConceroPool public poolReceiver;
    
    //Instantiate Scripts
    ConceroPoolDeploy public deployPool;
    ConceroDeploy public deployConcero;
    HelperConfig public helper;


    //Instantiate Chainlink Helpers
    CCIPLocalSimulator public ccipLocalSimulator;
    MockV3Aggregator public linkToUsdPriceFeeds;
    MockV3Aggregator public usdcToUsdPriceFeeds;
    MockV3Aggregator public nativeToUsdPriceFeeds;
    MockV3Aggregator public linkToNativePriceFeeds;

    uint64 private destinationChainSelector;
    BurnMintERC677Helper private cccipToken;
    address source_Router;

    uint8 public constant DECIMALS = 18;
    int256 public constant INITIAL_ANSWER = 1 * 10**18;

    //Instantiate Mocks
    USDC public mUSDC;
    uint256 private constant USDC_DECIMALS = 10**6;

    //Create Common Test Variables
    uint256 private constant INITIAL_BALANCE = 10 * USDC_DECIMALS;
    uint256 private constant POOL_INITIAL_BALANCE = 1000 * USDC_DECIMALS;
    uint256 private constant THRESHOLD = 10;

    // Mock Addresses
    address Barba = makeAddr("Barba");
    address lp = makeAddr("LiquidityProvider");
    address Athena = makeAddr("Athena");
    address Exploiter = makeAddr("Exploiter");
    address Messenger = makeAddr("Messenger");
    address UserReceiver = makeAddr("Receiver");

    function setUp() public {
        // Chainlink CCIP Local Environment
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

        // Chainlink Price Feed Variables
        linkToUsdPriceFeeds = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        usdcToUsdPriceFeeds = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        nativeToUsdPriceFeeds = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
        linkToNativePriceFeeds = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);

        //Initiate Global Variables with Chainlink Local Variables
        destinationChainSelector = chainSelector; //16015286601757825753
        cccipToken = (ccipBnM);
        source_Router = address(sourceRouter);

        //Deploy Mocks
        mUSDC = new USDC("USDC", "mUSDC", Barba, INITIAL_BALANCE);

        //Deploy Scripts for Contracts Deploys
        deployPool = new ConceroPoolDeploy();
        deployConcero = new ConceroDeploy();
        helper = new HelperConfig();

        //Deploy protocol Contracts
        pool = deployPool.run(address(linkToken), address(sourceRouter));
        poolReceiver = deployPool.run(address(linkToken), address(destinationRouter));
        concero = deployConcero.run(
            address(0),
            0,
            0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000,
            0,
            0,
            chainSelector,
            1,
            address(linkToken),
            address(sourceRouter),
            Concero.PriceFeeds ({
                linkToUsdPriceFeeds: address(linkToUsdPriceFeeds),
                usdcToUsdPriceFeeds: address(linkToUsdPriceFeeds),
                nativeToUsdPriceFeeds: address(nativeToUsdPriceFeeds),
                linkToNativePriceFeeds: address(linkToNativePriceFeeds)
            })
        );
        
        //Transfer ownership
        vm.startPrank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        pool.transferOwnership(Barba);
        poolReceiver.transferOwnership(Barba);
        concero.transferOwnership(Barba);
        vm.stopPrank();

        vm.prank(Barba);
        concero.acceptOwnership();

        //Distribute Ether Balance
        vm.deal(lp, INITIAL_BALANCE);
        vm.deal(Athena, INITIAL_BALANCE);

        //Distribute USDC Balance
        mUSDC.mint(lp, POOL_INITIAL_BALANCE);
        mUSDC.mint(Athena, INITIAL_BALANCE);

        //Distribute CCIP-BnM balance
        ccipBnM.drip(address(poolReceiver));
        ccipBnM.drip(address(pool));
        ccipBnM.drip(lp);

        //Distribute Link Token balance.
        ccipLocalSimulator.requestLinkFromFaucet(address(poolReceiver), INITIAL_BALANCE);
    }
    
    modifier setApprovals(){
        vm.startPrank(Barba);
        pool.setConceroOrchestrator(address(concero));
        pool.setMessenger(Messenger);
        pool.setConceroContractSender(destinationChainSelector, address(poolReceiver), 1);
        pool.setConceroPoolReceiver(destinationChainSelector, address(poolReceiver));

        pool.setSupportedToken(address(0), 1);
        pool.setSupportedToken(address(mUSDC), 1);
        pool.setSupportedToken(address(cccipToken), 1);

        pool.setApprovedSender(address(0), lp);
        pool.setApprovedSender(address(mUSDC), lp);
        pool.setApprovedSender(address(cccipToken), lp);

        poolReceiver.setConceroOrchestrator(address(concero));
        poolReceiver.setMessenger(Messenger);
        poolReceiver.setConceroContractSender(destinationChainSelector, address(pool), 1);
        poolReceiver.setConceroContractSender(destinationChainSelector, address(concero), 1);
        poolReceiver.setConceroPoolReceiver(destinationChainSelector, address(pool));

        poolReceiver.setSupportedToken(address(0), 1);
        poolReceiver.setSupportedToken(address(mUSDC), 1);
        poolReceiver.setSupportedToken(address(cccipToken), 1);

        poolReceiver.setApprovedSender(address(0), Messenger);
        poolReceiver.setApprovedSender(address(mUSDC), Messenger);
        poolReceiver.setApprovedSender(address(cccipToken), Messenger);

        concero.setConceroContract(destinationChainSelector, address(poolReceiver));
        vm.stopPrank();
        _;
    }

    //Checking Mock Token Decimals//
    function test_tokenDecimals() public view {
        assertEq(mUSDC.decimals(), 6);
    }
    
    //Checking Price Feed Mock
    function test_priceFeedsMock() public view {
        (, int256 nativeToUsdRate, , , ) = nativeToUsdPriceFeeds.latestRoundData();
        console2.log(nativeToUsdRate);
    }

    event Concero_CCIPSent();
    function test_wholeFlow() public setApprovals{
        //======= LP Deposits USDC on the Main Pool
        vm.startPrank(lp);
        mUSDC.approve(address(pool), POOL_INITIAL_BALANCE);
        pool.depositToken(address(mUSDC), POOL_INITIAL_BALANCE);
        vm.stopPrank();
        
        //======= We check the pool balance;
                    //Here, the LP Fees will be compounding directly for the LP address
        assertEq(mUSDC.balanceOf(address(pool)), POOL_INITIAL_BALANCE);

        //======= Messenger Transfers value to other cross-chain pool
                    //Empty data because it's a internal transfer
                    //We only pass data when it's a external one and we are using the LP money
                    //to pay users upfront
        uint256 crossChainPoolBalance = POOL_INITIAL_BALANCE / 2;
        vm.prank(Messenger);
        pool.ccipSendToPool(destinationChainSelector, address(mUSDC), crossChainPoolBalance);

        //======= Check pool's balances
        assertEq(mUSDC.balanceOf(address(pool)), crossChainPoolBalance);
        assertEq(mUSDC.balanceOf(address(poolReceiver)), crossChainPoolBalance);

        //======= Check if Messenger balance got updated on `poolReceiver`
                    //Here, we check the Messenger balance and not lp balance
                    //because the messenger will be the one will transfer money to other chains
                    //So, we are using the messenger address to allow transfer through whitelisted dst
                    //Also, the compounding in cross-chain dst will be made on top of the Messenger address.
        assertEq(poolReceiver.s_userBalances(address(mUSDC), Messenger), crossChainPoolBalance);

        //======= Starting a user transaction
        uint256 amountToTransfer = 1 * USDC_DECIMALS;
        vm.startPrank(Athena);
        mUSDC.approve(address(concero), 1 * USDC_DECIMALS);
        concero.startTransaction(address(mUSDC), IConceroCommon.CCIPToken.usdc, amountToTransfer, destinationChainSelector, address(poolReceiver));
        vm.stopPrank();
        //======= We are not mocking Functions here. Need to improve it.

        //======= Check the total balance on the poolReceiver contract
                //Sub the ConceroFee
        uint256 conceroFee = amountToTransfer / 1000;

        assertEq(mUSDC.balanceOf(address(poolReceiver)), (crossChainPoolBalance + amountToTransfer - conceroFee));
    
        //======= Check the total balance on the pool contract
                //Plus the ConceroFee
        assertEq(mUSDC.balanceOf(address(concero)), conceroFee);

        //======= Check the LP fee compounding
        assertEq(poolReceiver.s_userBalances(address(mUSDC), Messenger), crossChainPoolBalance + conceroFee);

        //======= Let's pretend that CLF did the Job and 'Orchestrator' will transfer funds to the user
        uint256 userValue = amountToTransfer - (conceroFee * 2);
        vm.prank(address(concero));
        poolReceiver.orchestratorLoan(address(mUSDC), userValue, UserReceiver);

        //======= Checks if the User received the correct amount
        assertEq(mUSDC.balanceOf(UserReceiver), userValue);
    }

}