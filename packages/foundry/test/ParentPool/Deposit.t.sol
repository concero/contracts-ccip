// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployParentPool} from "./deploy/DeployParentPool.sol";
import {console} from "../../lib/forge-std/src/console.sol";
import {ConceroParentPool} from "contracts/ConceroParentPool.sol";
import {IParentPool} from "contracts/Interfaces/IParentPool.sol";
import {IAny2EVMMessageReceiver} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "../../lib/chainlink-local/lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract Deposit is DeployParentPool {
    address public user1 = address(0x1);

    function setUp() public {
        deployPoolsInfra();
    }

    function test_startDeposit_Success() public {
        uint256 usdcAmount = 100 * 10 ** 6;

        vm.prank(user1);
        IParentPool(address(parentPoolProxy)).startDeposit(usdcAmount);
        vm.stopPrank();

        // Add assertions to verify storage changes
        // e.g., verify s_depositRequests, s_clfRequestTypes, emitted events, etc.
    }

    function test_sendCcipTx() public {
        deal(vm.envAddress("USDC_BASE"), address(parentPoolProxy), 10000000000000000000000);

        vm.prank(vm.envAddress("MESSENGER_ADDRESS"));
        IParentPool(address(parentPoolProxy)).distributeLiquidity(
            uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            10 * 10 ** 6,
            keccak256(abi.encodePacked("test"))
        );
        vm.stopPrank();
    }

    function test_ccipReceive() public {
        vm.selectFork(baseForkId);
        vm.prank(vm.envAddress("CL_CCIP_ROUTER_BASE"));

        Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](1);
        destTokenAmounts[0] = Client.EVMTokenAmount({
            token: vm.envAddress("USDC_BASE"),
            amount: 100000000
        });

        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked("test")),
            sourceChainSelector: uint64(vm.envUint("CL_CCIP_CHAIN_SELECTOR_ARBITRUM")),
            sender: abi.encode(user1),
            data: abi.encode(address(0), address(0), 0),
            destTokenAmounts: destTokenAmounts
        });

        IAny2EVMMessageReceiver(address(parentPoolProxy)).ccipReceive(message);
    }
}
