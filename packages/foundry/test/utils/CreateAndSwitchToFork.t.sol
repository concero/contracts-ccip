// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

enum ForkType {
    BASE,
    ARBITRUM,
    POLYGON
}

contract CreateAndSwitchToForkTest is Test {
    uint256 private forkId;

    function switchToFork(ForkType forkType) internal {
        if (forkType == ForkType.BASE) {
            forkId = vm.createFork(vm.envString("BASE_RPC_URL"), 17655883);
            vm.selectFork(forkId);
        }
    }
}
