"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const { SubscriptionManager } = require("@chainlink/functions-toolkit");
const { types } = require("hardhat/config");
const CLFnetworks_1 = require("../../../constants/CLFnetworks");
task("clf-deploy-auto-consumer", "Deploys the AutomatedFunctionsConsumer contract")
    .addParam("subid", "Billing subscription ID used to pay for Functions requests")
    .addOptionalParam("verify", "Set to true to verify consumer contract", false, types.boolean)
    .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
    .setAction(async (taskArgs) => {
    console.log("\n__Compiling Contracts__");
    await run("compile");
    const functionsRouterAddress = CLFnetworks_1.networks[network.name]["functionsRouter"];
    const donId = CLFnetworks_1.networks[network.name]["donId"];
    const donIdBytes32 = hre.ethers.utils.formatBytes32String(donId);
    const signer = await ethers.getSigner();
    const linkTokenAddress = CLFnetworks_1.networks[network.name]["linkToken"];
    const txOptions = { confirmations: CLFnetworks_1.networks[network.name].confirmations };
    const subscriptionId = taskArgs.subid;
    // Initialize SubscriptionManager
    const subManager = new SubscriptionManager({ signer, linkTokenAddress, functionsRouterAddress });
    await subManager.initialize();
    console.log(`Deploying AutomatedFunctionsConsumer contract to ${network.name}`);
    const autoConsumerContractFactory = await ethers.getContractFactory("AutomatedFunctionsConsumer");
    const autoConsumerContract = await autoConsumerContractFactory.deploy(functionsRouterAddress, donIdBytes32);
    console.log(`\nWaiting 1 block for transaction ${autoConsumerContract.deployTransaction.hash} to be confirmed...`);
    await autoConsumerContract.deployTransaction.wait(1);
    const consumerAddress = autoConsumerContract.address;
    console.log(`\nAdding ${consumerAddress} to subscription ${subscriptionId}...`);
    const addConsumerTx = await subManager.addConsumer({ subscriptionId, consumerAddress, txOptions });
    console.log(`\nAdded consumer contract ${consumerAddress} in Tx: ${addConsumerTx.transactionHash}`);
    const verifyContract = taskArgs.verify;
    if (network.name !== "localFunctionsTestnet" &&
        verifyContract &&
        !!CLFnetworks_1.networks[network.name].verifyApiKey &&
        CLFnetworks_1.networks[network.name].verifyApiKey !== "UNSET") {
        try {
            console.log(`\nVerifying contract ${consumerAddress}...`);
            await autoConsumerContract.deployTransaction.wait(Math.max(6 - CLFnetworks_1.networks[network.name].confirmations, 0));
            await run("verify:verify", {
                address: consumerAddress,
                constructorArguments: [functionsRouterAddress, donIdBytes32],
            });
            console.log("Contract verified");
        }
        catch (error) {
            if (!error.message.includes("Already Verified")) {
                console.log("Error verifying contract.  Delete the build folder and try again.");
                console.log(error);
            }
            else {
                console.log("Contract already verified");
            }
        }
    }
    else if (verifyContract && network.name !== "localFunctionsTestnet") {
        console.log("\nPOLYGONSCAN_API_KEY, ETHERSCAN_API_KEY or FUJI_SNOWTRACE_API_KEY is missing. Skipping contract verification...");
    }
    console.log(`\nAutomatedFunctionsConsumer contract deployed to ${consumerAddress} on ${network.name}`);
});
exports.default = {};
