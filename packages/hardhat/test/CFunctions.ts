import { ethers, deployments, getNamedAccounts } from "hardhat";
import { expect } from "chai";
import { CFunctions } from "../typechain-types";
import "@nomicfoundation/hardhat-chai-matchers";

describe("CFunctions", function() {
  let cFunctions: CFunctions;
  let deployer: string;
  let nikita: string;

  const ccipMessageId = "0x2b346e2ea0f849048bfb59996e02f0082df9298550249d7c6cefec78e7e24cd8";
  const sender = "0x70E73f067a1fC9FE6D53151bd271715811746d3a";
  const recipient = "0x70E73f067a1fC9FE6D53151bd271715811746d3a";
  const amount = ethers.parseEther("1"); // 1 ether
  const srcChainSelector = 12532609583862916517n;
  const token = "0x9999f7Fea5938fD3b1E26A12c3f2fb024e194f97";

  before(async () => {
    const namedAccounts = await getNamedAccounts();
    deployer = namedAccounts.deployer;
    nikita = namedAccounts.nikita;

    await deployments.fixture(["CFunctions"]); // Deploy using named deployment script
    cFunctions = await ethers.getContract("CFunctions", deployer);
  });

  describe("addUnconfirmedTX", function() {
    it("should fail when called by an address not on the allowlist", async function() {
      // Assuming `anotherAccount` is not on the allowlist
      const anotherAccount = await ethers.getSigner(nikita);

      await expect(cFunctions.connect(anotherAccount).addUnconfirmedTX(ccipMessageId, sender, recipient, amount, srcChainSelector, token))
        .to.be.revertedWithCustomError(cFunctions, "NotAllowed");
    });
    it("should add a new unconfirmed transaction successfully", async function() {
      // Retrieve a signer with the ability to sign transactions
      const signer = await ethers.getSigner(deployer);

      await expect(cFunctions.connect(signer).addUnconfirmedTX(ccipMessageId, sender, recipient, amount, srcChainSelector, token))
        .to.emit(cFunctions, "UnconfirmedTXAdded")
        .withArgs(ccipMessageId, sender, recipient, amount, token);
    });

    it("should throw customError when adding a transaction with a duplicate ccipMessageId", async function() {
      const signer = await ethers.getSigner(deployer);

      // The second call with the same ccipMessageId should revert
      await expect(cFunctions.connect(signer).addUnconfirmedTX(ccipMessageId, sender, recipient, amount, srcChainSelector, token))
        .to.be.revertedWithCustomError(cFunctions, "TXAlreadyExists");
    });
  });
});
