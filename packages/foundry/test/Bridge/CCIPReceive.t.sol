// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.20;

// import {StartBridgeTest} from "./StartBridge.t.sol";

// contract CCIPReceiveTest is StartBridgeTest {
//     /*//////////////////////////////////////////////////////////////
//                                  SETUP
//     //////////////////////////////////////////////////////////////*/
//     function setUp() public virtual override {
//         StartBridgeTest.setUp();
//     }

//     function test_ccipReceive_batched_tx_success() public {
//         // create batched tx message
//         // prank router
//         // call ccipReceive on parentPool
//         // assert s_loansInUse -= any2EvmMessage.destTokenAmounts[0].amount;
//         // assert emitted event contained correct token amount

//         /**
//          * emit ConceroParentPool_CCIPReceived(
//          *         any2EvmMessage.messageId,
//          *         any2EvmMessage.sourceChainSelector,
//          *         abi.decode(any2EvmMessage.sender, (address)),
//          *         any2EvmMessage.destTokenAmounts[0].token,
//          *         any2EvmMessage.destTokenAmounts[0].amount
//          *     );
//          */
//     }
// }
