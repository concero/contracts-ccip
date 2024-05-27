"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("hardhat/config");
const { types } = require("hardhat/config");
const CLFnetworks_1 = require("../../../constants/CLFnetworks");
(0, config_1.task)("clf-deploy-consumer", "Deploys the FunctionsConsumer contract")
    .addOptionalParam("verify", "Set to true to verify contract", false, types.boolean)
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    console.log(`Deploying FunctionsConsumer contract to ${network.name}`);
    const functionsRouter = CLFnetworks_1.networks[network.name]["functionsRouter"];
    const donIdBytes32 = hre.ethers.utils.formatBytes32String(CLFnetworks_1.networks[network.name]["donId"]);
    console.log("\n__Compiling Contracts__");
    await run("compile");
    const overrides = {};
    // If specified, use the gas price from the network config instead of Ethers estimated price
    if (CLFnetworks_1.networks[network.name].gasPrice) {
        overrides.gasPrice = CLFnetworks_1.networks[network.name].gasPrice;
    }
    // If specified, use the nonce from the network config instead of automatically calculating it
    if (CLFnetworks_1.networks[network.name].nonce) {
        overrides.nonce = CLFnetworks_1.networks[network.name].nonce;
    }
    const consumerContractFactory = await ethers.getContractFactory("FunctionsConsumer");
    const consumerContract = await consumerContractFactory.deploy(functionsRouter, donIdBytes32, overrides);
    console.log(`\nWaiting ${CLFnetworks_1.networks[network.name].confirmations} blocks for transaction ${consumerContract.deployTransaction.hash} to be confirmed...`);
    await consumerContract.deployTransaction.wait(CLFnetworks_1.networks[network.name].confirmations);
    console.log("\nDeployed FunctionsConsumer contract to:", consumerContract.address);
    if (network.name === "localFunctionsTestnet") {
        return;
    }
    const verifyContract = taskArgs.verify;
    if (network.name !== "localFunctionsTestnet" &&
        verifyContract &&
        !!CLFnetworks_1.networks[network.name].verifyApiKey &&
        CLFnetworks_1.networks[network.name].verifyApiKey !== "UNSET") {
        try {
            console.log("\nVerifying contract...");
            await run("verify:verify", {
                address: consumerContract.address,
                constructorArguments: [functionsRouter, donIdBytes32],
            });
            console.log("Contract verified");
        }
        catch (error) {
            if (!error.message.includes("Already Verified")) {
                console.log("Error verifying contract.  Ensure you are waiting for enough confirmation blocks, delete the build folder and try again.");
                console.log(error);
            }
            else {
                console.log("Contract already verified");
            }
        }
    }
    else if (verifyContract && network.name !== "localFunctionsTestnet") {
        console.log("\nScanner API key is missing. Skipping contract verification...");
    }
    console.log(`\nFunctionsConsumer contract deployed to ${consumerContract.address} on ${network.name}`);
});
exports.default = {};
