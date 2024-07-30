// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";

contract TestnetParentPoolDeploy is Script {
    address _proxy = 0x4f4549e3349144C1eFD843f778FDcAaAbc65C9E3;
    address _link = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
    bytes32 _donId = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;
    uint64 _subscriptionId = 16;
    address _functionsRouter = 0xf9B8fc078197181C841c296C876945aaa425B278;
    address _ccipRouter = 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93;
    address _usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address _lpToken = address(0);
    address _automation = address(0);
    address _orchestrator = address(0);
    address _owner = 0xd2Cb8786C0Ec3680C55C9256371F3577fE1C6A9e;
    address[3] _msgrs = [vm.envAddress("MESSENGER_0_ADDRESS"), address(0), address(0)];

    function run() public returns (ConceroParentPool pool) {
        vm.startBroadcast();
        pool = new ConceroParentPool(
            _proxy,
            _link,
            _donId,
            _subscriptionId,
            _functionsRouter,
            _ccipRouter,
            _usdc,
            _lpToken,
            _automation,
            _orchestrator,
            _owner,
            _msgrs
        );
        vm.stopBroadcast();
    }
}
