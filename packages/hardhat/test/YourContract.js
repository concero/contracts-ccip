"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const hardhat_1 = require("hardhat");
describe("YourContract", function () {
    // We define a fixture to reuse the same setup in every test.
    let yourContract;
    before(async () => {
        const [owner] = await hardhat_1.ethers.getSigners();
        const yourContractFactory = await hardhat_1.ethers.getContractFactory("YourContract");
        yourContract = (await yourContractFactory.deploy(owner.address));
        await yourContract.waitForDeployment();
    });
    describe("Deployment", function () {
        it("Should have the right message on deploy", async function () {
            (0, chai_1.expect)(await yourContract.greeting()).to.equal("Building Unstoppable Apps!!!");
        });
        it("Should allow setting a new message", async function () {
            const newGreeting = "Learn Scaffold-ETH 2! :)";
            await yourContract.setGreeting(newGreeting);
            (0, chai_1.expect)(await yourContract.greeting()).to.equal(newGreeting);
        });
    });
});
