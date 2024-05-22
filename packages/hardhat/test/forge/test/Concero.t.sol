// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {Concero} from "contracts/Concero.sol";

bytes32 constant CCIP_MESSAGE_ID = 0x7488ba033a94f37b22acb64fafab9d00aabff29c3f325dfcf4a217767b2bede2;
string constant BASE_SEPOLIA_RPC = "https://sepolia.base.org";
uint256 constant BASE_SEPOLIA_END_FORK_BLOCK_NUMBER = 9480039;

contract ConceroConfirmTxTest is Test {
  ConceroMock public concero;
  uint256 public baseForkId;

  function setUp() public {
    concero = new ConceroMock();
    //    baseForkId = vm.createFork(BASE_SEPOLIA_RPC, BASE_SEPOLIA_END_FORK_BLOCK_NUMBER);
  }

  function test_confirmTx() public {
    //    vm.selectFork(baseForkId);

    concero.mock_confirmTx(CCIP_MESSAGE_ID);
    Concero.Transaction memory transaction = concero.getTransaction(CCIP_MESSAGE_ID);
    assert(transaction.isConfirmed == true);
  }
}

contract ConceroMock is Concero {
  constructor()
    Concero(
      0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
      0,
      0x0,
      0,
      0,
      3734403246176062136,
      0,
      0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
      0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
      PriceFeeds({
        linkToUsdPriceFeeds: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
        usdcToUsdPriceFeeds: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
        nativeToUsdPriceFeeds: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
        linkToNativePriceFeeds: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846
      })
    )
  {
    transactions[CCIP_MESSAGE_ID] = Transaction({
      ccipMessageId: CCIP_MESSAGE_ID,
      sender: 0x70E73f067a1fC9FE6D53151bd271715811746d3a,
      recipient: 0x70E73f067a1fC9FE6D53151bd271715811746d3a,
      amount: 1000000000000,
      token: CCIPToken.bnm,
      srcChainSelector: 4949039107694359620,
      isConfirmed: false
    });
  }

  function getTransaction(bytes32 ccipMessageId) public view returns (Transaction memory) {
    return transactions[ccipMessageId];
  }

  function mock_confirmTx(bytes32 ccipMessageId) public {
    _confirmTX(ccipMessageId, transactions[ccipMessageId]);
  }
}
