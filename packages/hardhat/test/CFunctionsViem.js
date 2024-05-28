"use strict";
// import { deployments, ethers, getNamedAccounts } from "hardhat";
// import { expect } from "chai";
// import { CFunctions } from "../artifacts/contracts/CFunctions.sol";
//
// describe("CFunctions", function () {
//   let cFunctions: CFunctions;
//   let deployer;
//
//   const ccipMessageId = "0x2a326e9ea0f849048bfb59996e02f0082df9298550249d7c6cefec78e7e24cd8";
//   const sender = "0x70E73f067a1fC9FE6D53151bd271715811746d3a";
//   const recipient = "0x70E73f067a1fC9FE6D53151bd271715811746d3a";
//   const amount = ethers.parseEther("1"); // 1 ether
//   const srcChainSelector = 12532609583862916517;
//   const token = "0x9999f7Fea5938fD3b1E26A12c3f2fb024e194f97";
//
//   before(async () => {
//     deployer = (await getNamedAccounts()).deployer;
//     await deployments.fixture(["CFunctions"]); // Ensure we're using the same deployment fixtures
//
//     cFunctions = await ethers.getContract("CFunctions", deployer);
//   });
//
//   describe("addUnconfirmedTX", function () {
//     it("should add a new unconfirmed transaction successfully", async function () {
//       await expect(
//         cFunctions
//           .connect(ethers.provider.getSigner(deployer))
//           .addUnconfirmedTX(ccipMessageId, sender, recipient, amount, srcChainSelector, token),
//       )
//         .to.emit(cFunctions, "UnconfirmedTXAdded")
//         .withArgs(ccipMessageId, sender, recipient, amount, token);
//     });
//
//     it("should fail when adding a transaction with a duplicate ccipMessageId", async function () {
//       // The first call should succeed
//       await cFunctions
//         .connect(ethers.provider.getSigner(deployer))
//         .addUnconfirmedTX(ccipMessageId, sender, recipient, amount, srcChainSelector, token);
//
//       // The second call with the same ccipMessageId should revert
//       await expect(
//         cFunctions
//           .connect(ethers.provider.getSigner(deployer))
//           .addUnconfirmedTX(ccipMessageId, sender, recipient, amount, srcChainSelector, token),
//       ).to.be.revertedWith("TXAlreadyExists");
//     });
//   });
// });
