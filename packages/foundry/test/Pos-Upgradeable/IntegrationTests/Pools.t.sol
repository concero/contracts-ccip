// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";

//====== Master Pool
import {ConceroPoolDeploy} from "../../../script/ConceroPoolDeploy.s.sol";
import {MasterPoolProxyDeploy} from "../../../script/MasterPoolProxyDeploy.s.sol";
import {ConceroPool} from "contracts/ConceroPool.sol";
import {MasterPoolProxy} from "contracts/Proxy/MasterPoolProxy.sol";

//====== Child Pool
import {ChildPoolDeploy} from "../../../script/ChildPoolDeploy.s.sol";
import {ChildPoolProxyDeploy} from "../../../script/ChildPoolProxyDeploy.s.sol";
import {ConceroChildPool} from "contracts/ConceroChildPool.sol";
import {ChildPoolProxy} from "contracts/Proxy/ChildPoolProxy.sol";

//====== Automation
import {AutomationDeploy} from "../../../script/AutomationDeploy.s.sol";
import {ConceroAutomation} from "contracts/ConceroAutomation.sol";

//====== LPToken
import {LPTokenDeploy} from "../../../script/LPTokenDeploy.s.sol";
import {LPToken} from "contracts/LPToken.sol";

//====== OpenZeppelin
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

//====== Chainlink Solutions
import {CCIPLocalSimulator, IRouterClient, WETH9, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

//===== Mocks
import {USDC} from "../../Mocks/USDC.sol";

contract PoolsTesting is Test{
    //====== Instantiate Master Pool
    ConceroPoolDeploy masterDeploy;
    MasterPoolProxyDeploy masterProxyDeploy;
    ConceroPool master;
    MasterPoolProxy masterProxy;
    ConceroPool wMaster;

    //====== Instantiate Child Pool
    ChildPoolDeploy childDeploy;
    ChildPoolProxyDeploy childProxyDeploy;
    ConceroChildPool child;
    ChildPoolProxy childProxy;
    ConceroChildPool wChild;

    //====== Instantiate Automation
    AutomationDeploy autoDeploy;
    ConceroAutomation automation;

    //====== Instantiate LPToken
    LPTokenDeploy lpDeploy;
    LPToken lp;

    //====== Instantiate Transparent Proxy Interfaces
    ITransparentUpgradeableProxy masterInterface;
    ITransparentUpgradeableProxy childInterface;

    //====== Instantiate Chainlink Solutions
    CCIPLocalSimulator public ccipLocalSimulator;    
    uint64 chainSelector;
    IRouterClient sourceRouter;
    IRouterClient destinationRouter;
    WETH9 wrappedNative;
    LinkToken linkToken;

    //====== Instantiate Mocks
    USDC usdc;
    uint256 private constant USDC_INITIAL_BALANCE = 500 * 10**6;

    address proxyOwner = makeAddr("owner");
    address Tester = makeAddr("Tester");
    address LiquidityProvider = makeAddr("LiquidityProvider");
    address Athena = makeAddr("Athena");
    address Concero = makeAddr("Concero");
    address ConceroDst = makeAddr("ConceroDst");
    address Orchestrator = makeAddr("Orchestrator");
    address Messenger = makeAddr("Messenger");
    address Forwarder = makeAddr("Forwarder");
    
    address mockFunctionsRouter = makeAddr("0x08");

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            chainSelector,
            sourceRouter,
            destinationRouter,
            wrappedNative,
            linkToken,
            ,
            
        ) = ccipLocalSimulator.configuration();

        usdc = new USDC("USDC", "USDC", Tester, USDC_INITIAL_BALANCE);

        //////////////////////////////////////////////
        /////////////// DEPLOY SCRIPTS ///////////////
        //////////////////////////////////////////////
        //====== Deploy Master Pool scripts
        masterDeploy = new ConceroPoolDeploy();
        masterProxyDeploy = new MasterPoolProxyDeploy();

        //====== Deploy Child Pool scripts
        childDeploy = new ChildPoolDeploy();
        childProxyDeploy = new ChildPoolProxyDeploy();

        //====== Deploy Automation scripts
        autoDeploy = new AutomationDeploy();

        //====== Deploy LPToken scripts
        lpDeploy = new LPTokenDeploy();

        ////////////////////////////////////////////////
        /////////////// DEPLOY CONTRACTS ///////////////
        ////////////////////////////////////////////////

        //Dummy address initially
        masterProxy = masterProxyDeploy.run(address(usdc), proxyOwner, Tester, "");
        masterInterface = ITransparentUpgradeableProxy(address(masterProxy));

        lp = lpDeploy.run(Tester, address(masterProxy));

        //====== Deploy Automation contract
        automation = autoDeploy.run(
            0x66756e2d626173652d6d61696e6e65742d310000000000000000000000000000, //_donId
            15, //_subscriptionId
            2, //_slotId
            0, //_secretsVersion
            0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124, //_srcJsHashSum
            0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173, //_dstJsHashSum
            0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124, //_ethersHashSum
            0xf9B8fc078197181C841c296C876945aaa425B278, //_router,
            address(masterProxy),
            Tester //_owner
        );

        master = masterDeploy.run(
            address(masterProxy),
            address(linkToken),
            0,
            0,
            mockFunctionsRouter,
            address(sourceRouter),
            address(usdc),
            address(lp),
            address(automation),
            Orchestrator,
            Tester
        );

        //Dummy address initially
        childProxy = childProxyDeploy.run(address(usdc), proxyOwner, Tester, "");
        childInterface = ITransparentUpgradeableProxy(address(childProxy));
        child = childDeploy.run(
            address(childProxy),
            address(linkToken),
            address(destinationRouter),
            address(usdc),
            Orchestrator,
            Tester
        );

        ///////////////////////////////////////////////
        /////////////// UPGRADE PROXIES ///////////////
        ///////////////////////////////////////////////
        vm.startPrank(proxyOwner);
        masterInterface.upgradeToAndCall(address(master), "");
        childInterface.upgradeToAndCall(address(child), "");
        vm.stopPrank();

        /////////////////////////////////////////////
        /////////////// LPToken ROLES ///////////////
        /////////////////////////////////////////////
        vm.startPrank(Tester);
        lp.grantRole(keccak256("CONTRACT_MANAGER"), Athena);
        lp.grantRole(keccak256("MINTER_ROLE"), address(masterProxy));
        vm.stopPrank();

        //////////////////////////////////////////////////////
        /////////////// WRAP PROXY & CONTRACTS ///////////////
        //////////////////////////////////////////////////////
        wMaster = ConceroPool(payable(address(masterProxy)));
        wChild = ConceroChildPool(payable(address(childProxy)));

        /// FAUCET
        ccipLocalSimulator.requestLinkFromFaucet(address(wMaster), 10 * 10**18);
        ccipLocalSimulator.requestLinkFromFaucet(address(wChild), 10 * 10**18);
        ccipLocalSimulator.supportNewToken(address(usdc));
        usdc.mint(LiquidityProvider, USDC_INITIAL_BALANCE);
    }

    modifier setters {
        //====== Master Setters
        vm.startPrank(Tester);
        wMaster.setPoolsToSend(chainSelector, address(wChild));
        assertEq(wMaster.s_poolToSendTo(chainSelector), address(wChild));

        wMaster.setConceroContractSender(chainSelector, address(wChild), 1);
        assertEq(wMaster.s_poolToReceiveFrom(chainSelector, address(wChild)), 1);

        wMaster.setConceroContractSender(chainSelector, address(ConceroDst), 1);
        assertEq(wMaster.s_poolToReceiveFrom(chainSelector, address(ConceroDst)), 1);

        wMaster.setPoolCap(USDC_INITIAL_BALANCE);

        //====== Child Setters

        wChild.setPoolsToSend(chainSelector, address(wMaster));
        assertEq(wChild.s_poolToSendTo(chainSelector), address(wMaster));

        wChild.setConceroContractSender(chainSelector, address(wMaster), 1);
        assertEq(wChild.s_poolToReceiveFrom(chainSelector, address(wMaster)), 1);

        wChild.setConceroContractSender(chainSelector, address(Concero), 1);
        assertEq(wChild.s_poolToReceiveFrom(chainSelector, address(Concero)), 1);

        //====== Automation Setters

        automation.setForwarderAddress(Forwarder);
        // automation.setDonHostedSecretsVersion()

        vm.stopPrank();
        _;
    }

    error ConceroChildPool_InsufficientBalance();
    function test_localDepositLiquidity() public setters{
        uint256 amountToDeposit = 150 * 10**6;
        uint256 amountLpShouldBeEmitted = 150 * 10**18;
        uint256 mockedFeeAccrued = 3*10**6;
        uint256 loanAmount = 1 * 10**6;
        uint256 biggerLoanAmount = 20 * 10**6;

        //====== Initiate the Deposit + Cross-chain transfer
        assertEq(usdc.balanceOf(address(wMaster)), 0);
        assertEq(usdc.balanceOf(address(wChild)), 0);

        vm.startPrank(LiquidityProvider);
        usdc.approve(address(wMaster), amountToDeposit);
        wMaster.depositLiquidity(amountToDeposit);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(wMaster)), amountToDeposit/2);
        assertEq(usdc.balanceOf(address(wChild)), amountToDeposit/2);

        //===== Check User LP balance
        assertEq(lp.balanceOf(LiquidityProvider), 0);

        //===== Adjust manually the LP emission
        wMaster.updateUSDCAmountManually(LiquidityProvider, amountToDeposit, amountToDeposit);

        //===== Check User LP balance
        assertEq(lp.balanceOf(LiquidityProvider), amountLpShouldBeEmitted);
        
        //===== Mocking some fees
        usdc.mint(address(wMaster), mockedFeeAccrued);
        usdc.mint(address(wChild), mockedFeeAccrued);
        assertEq(usdc.balanceOf(address(wMaster)), (amountToDeposit/2) + mockedFeeAccrued);
        assertEq(usdc.balanceOf(address(wChild)), (amountToDeposit/2) + mockedFeeAccrued);

        //===== User initiate an withdrawRequest
        //Withdraw only 1/3 of deposited == 150*10**18 / 3;
        vm.prank(LiquidityProvider);
        wMaster.startWithdrawal(50 * 10**18);

        //===== Adjust manually the USDC cross-chain total
        wMaster.updateUSDCAmountEarned(LiquidityProvider, 78*10**6);

        //===== Take a loan on child pool
        assertEq(usdc.balanceOf(Athena), 0);

        vm.prank(Orchestrator);
        wChild.orchestratorLoan(address(usdc), loanAmount, Athena);

        assertEq(usdc.balanceOf(Athena), loanAmount);

        //===== Advance in time
        vm.warp(7 days);

        //==== Mock the Automation call to ChildPool
        vm.prank(Messenger);
        wChild.ccipSendToPool(chainSelector, LiquidityProvider, 25_740_000);

        //==== Mock complete withdraw
        vm.startPrank(LiquidityProvider);
        lp.approve(address(wMaster), 50 *10**18);
        wMaster.completeWithdrawal();
        vm.stopPrank();

        //===== Take a loan on child pool
        assertEq(usdc.balanceOf(Athena), loanAmount);

        vm.prank(Orchestrator);
        wChild.orchestratorLoan(address(usdc), biggerLoanAmount, Athena);

        assertEq(usdc.balanceOf(Athena), loanAmount + biggerLoanAmount);

        //==== Mock the Automation call to ChildPool
        vm.prank(Messenger);
        vm.expectRevert(abi.encodeWithSelector(ConceroChildPool_InsufficientBalance.selector));
        wChild.ccipSendToPool(chainSelector, LiquidityProvider, (amountToDeposit/2) - ((amountToDeposit/2))/2);
    }
}