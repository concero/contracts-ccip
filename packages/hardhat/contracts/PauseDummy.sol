// SPDX-License-Identifier: UNLICENSED
// deployed with salt: 0xdddd5f804b9d293dce8819d232e8d76381605a62f2d34c122b9ca6815a0000c8
// to address: 0x00c4d25487297C4fc1341aa840a4F56e474f6A0d
pragma solidity ^0.8.20;

contract PauseDummy {
  fallback() external {
    revert("paused");
  }
  receive() external payable {
    revert("paused");
  }
}
