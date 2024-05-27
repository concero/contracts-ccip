"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const CNetworks_1 = __importDefault(require("../../constants/CNetworks"));
const config_1 = require("hardhat/config");
const functions_toolkit_1 = require("@chainlink/functions-toolkit");
(0, config_1.task)("clf-sub-consumer-rm", "Removes consumer contracts from a Functions billing subscription")
    .addOptionalParam("subid", "Subscription ID", undefined, config_1.types.int)
    .addOptionalParam("contract", "Address(es) of the consumer contract to remove or keep")
    .addOptionalParam("onlykeepcontract", "If specified, removes all except this address", undefined, config_1.types.string)
    .setAction(async ({ subid, contract, onlykeepcontract }, { ethers, network }) => {
    ensureSupportedChain(network.name);
    const signer = await ethers.getSigner();
    const chainConfig = getChainConfig(network.name);
    const subscriptionId = subid || chainConfig.functionsSubIds[0];
    const sm = await initializeSubscriptionManager(signer, chainConfig);
    if (onlykeepcontract) {
        await handleSelectiveRemoval(sm, subscriptionId, onlykeepcontract);
    }
    else {
        await handleDirectRemoval(sm, subscriptionId, contract.split(","));
    }
});
function ensureSupportedChain(chainName) {
    if (!CNetworks_1.default[chainName]) {
        throw new Error(`Chain ${chainName} not supported`);
    }
}
function getChainConfig(chainName) {
    return CNetworks_1.default[chainName];
}
async function initializeSubscriptionManager(signer, { linkToken, functionsRouter, confirmations }) {
    const sm = new functions_toolkit_1.SubscriptionManager({
        signer,
        linkTokenAddress: linkToken,
        functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();
    return sm;
}
async function handleSelectiveRemoval(sm, subscriptionId, onlykeepcontract) {
    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    const consumersToKeep = [onlykeepcontract.toLowerCase()];
    const consumersToRemove = subInfo.consumers.filter(consumer => !consumersToKeep.includes(consumer.toLowerCase()));
    console.log(`Removing consumers: ${consumersToRemove.join(", ")}, keeping: ${onlykeepcontract}`);
    for (const consumerAddress of consumersToRemove) {
        await removeConsumer(sm, subscriptionId, consumerAddress);
    }
}
async function handleDirectRemoval(sm, subscriptionId, consumerAddresses) {
    for (const consumerAddress of consumerAddresses) {
        await removeConsumer(sm, subscriptionId, consumerAddress);
    }
}
async function removeConsumer(sm, subscriptionId, consumerAddress) {
    console.log(`Removing ${consumerAddress} from subscription ${subscriptionId}...`);
    const removeConsumerTx = await sm.removeConsumer({ subscriptionId, consumerAddress });
    console.log(`Removed ${consumerAddress} from subId ${subscriptionId}. Tx: ${removeConsumerTx.transactionHash}`);
}
exports.default = {};
