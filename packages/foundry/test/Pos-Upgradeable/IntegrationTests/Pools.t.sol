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
    uint256 private constant USDC_INITIAL_BALANCE = 150 * 10**6;

    address proxyOwner = makeAddr("owner");
    address Tester = makeAddr("Tester");
    address Athena = makeAddr("Athena");
    address Orchestrator = makeAddr("Orchestrator");
    address Messenger = makeAddr("Messenger");
    
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
        child = childDeploy.run(
            address(childProxy),
            address(linkToken),
            address(destinationRouter),
            address(usdc),
            Orchestrator,
            Tester
        );

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
    }

    
}