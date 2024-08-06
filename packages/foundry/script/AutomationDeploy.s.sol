// // SPDX-License-Identifier: UNLICENSED
// pragma solidity 0.8.20;

// import {Script, console2} from "../lib/forge-std/src/Script.sol";
// import {ConceroAutomation} from "contracts/ConceroAutomation.sol";

// contract AutomationDeploy is Script {
//     function run(
//         bytes32 _donId,
//         uint64 _subscriptionId,
//         uint8 _slotId,
//         address _router,
//         address _masterPool,
//         address _owner
//     ) public returns (ConceroAutomation automation) {
//         vm.startBroadcast();
//         automation = new ConceroAutomation(_donId, _subscriptionId, _slotId, _router, _masterPool, _owner);
//         vm.stopBroadcast();
//     }
// }
