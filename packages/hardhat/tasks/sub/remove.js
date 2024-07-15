"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const CNetworks_2 = __importDefault(require("../../constants/CNetworks"));
const config_2 = require("hardhat/config");
const functions_toolkit_2 = require("@chainlink/functions-toolkit");
(0, config_2.task)("clf-sub-consumer-rm", "Removes consumer contracts from a Functions billing subscription")
    .addOptionalParam("subid", "Subscription ID", undefined, config_2.types.int)
    .addOptionalParam("contract", "Address(es) of the consumer contract to remove or keep")
    .addOptionalParam("keepcontracts", "If specified, removes all except this address", undefined, config_2.types.string)
    .setAction(async ({ subid, contract, keepcontracts }, { ethers, network }) => {
    const signer = await ethers.getSigner();
    const { functionsSubIds, linkToken, functionsRouter, confirmations } = CNetworks_2.default[hre.network.name];
    const subscriptionId = subid || functionsSubIds[0];
    const txOptions = { confirmations, overrides: { gasLimit: 500000n } };
    const sm = new functions_toolkit_2.SubscriptionManager({
        signer,
        linkTokenAddress: linkToken,
        functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();
    if (keepcontracts) {
        await handleSelectiveRemoval(sm, subscriptionId, keepcontracts, txOptions);
    }
    else {
        await handleDirectRemoval(sm, subscriptionId, contract.split(","), txOptions);
    }
});
async function handleSelectiveRemoval(sm, subscriptionId, keepcontracts, txOptions) {
    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    const consumersToKeep = keepcontracts.split(",").map(consumer => consumer.toLowerCase());
    const consumersToRemove = subInfo.consumers.filter(consumer => !consumersToKeep.includes(consumer.toLowerCase()));
    console.log(`Removing consumers: ${consumersToRemove.join(", ")}, keeping: ${keepcontracts}`);
    for (const consumerAddress of consumersToRemove) {
        await removeConsumer(sm, subscriptionId, consumerAddress, txOptions);
    }
}
async function handleDirectRemoval(sm, subscriptionId, consumerAddresses, txOptions) {
    for (const consumerAddress of consumerAddresses) {
        await removeConsumer(sm, subscriptionId, consumerAddress, txOptions);
    }
}
async function removeConsumer(sm, subscriptionId, consumerAddress, txOptions) {
    try {
        console.log(`Removing ${consumerAddress} from subscription ${subscriptionId}...`);
        const removeConsumerTx = await sm.removeConsumer({ subscriptionId, consumerAddress, txOptions });
        console.log(`Removed ${consumerAddress} from subId ${subscriptionId}. Tx: ${removeConsumerTx.transactionHash}`);
    }
    catch (error) {
        console.error(`Failed to remove ${consumerAddress} from subscription ${subscriptionId}: ${error.message}`);
    }
}
exports.default = {};
