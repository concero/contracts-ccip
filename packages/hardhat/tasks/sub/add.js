"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const functions_toolkit_2 = require("@chainlink/functions-toolkit");
const CNetworks_2 = __importDefault(require("../../constants/CNetworks"));
const config_2 = require("hardhat/config");
const log_1 = __importDefault(require("../../utils/log"));
// run with: bunx hardhat clf-consumer-add --subid 5810 --contract 0x... --network avalancheFuji
(0, config_2.task)("clf-sub-consumer-add", "Adds a consumer contract to the Functions billing subscription")
    .addOptionalParam("subid", "Subscription ID", undefined)
    .addParam("contract", "Address(es) of the Functions consumer contract to authorize for billing")
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const { name } = hre.network;
    if (!CNetworks_2.default[name])
        throw new Error(`Chain ${name} not supported`);
    const consumerAddress = taskArgs.contract;
    let subscriptionId;
    if (!taskArgs.subid) {
        console.log(`No subscription ID provided, defaulting to ${CNetworks_2.default[name].functionsSubIds[0]}`);
        subscriptionId = CNetworks_2.default[name].functionsSubIds[0];
    }
    else
        subscriptionId = parseInt(taskArgs.subId);
    const consumerAddresses = taskArgs.contract.split(",");
    await addCLFConsumer(CNetworks_2.default[name], consumerAddresses, subscriptionId);
});
async function addCLFConsumer(chain, consumerAddresses, subscriptionId) {
    const { linkToken, functionsRouter, confirmations, name, url } = chain;
    const signer = await hre.ethers.getSigner(process.env.DEPLOYER_ADDRESS);
    for (const consumerAddress of consumerAddresses) {
        const txOptions = { confirmations };
        (0, log_1.default)(`Adding ${consumerAddress} to sub ${subscriptionId} on ${name}`, "addCLFConsumer");
        const sm = new functions_toolkit_2.SubscriptionManager({
            signer,
            linkTokenAddress: linkToken,
            functionsRouterAddress: functionsRouter,
        });
        await sm.initialize();
        try {
            const addConsumerTx = await sm.addConsumer({ subscriptionId, consumerAddress, txOptions });
            (0, log_1.default)(`Successfully added ${consumerAddress} to sub ${subscriptionId} on ${name}.`, "addCLFConsumer");
        }
        catch (error) {
            if (error.message.includes("is already authorized to use subscription"))
                (0, log_1.default)(error.message, "deployConcero");
            else
                console.error(error);
        }
    }
}
exports.default = addCLFConsumer;
