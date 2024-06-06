"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_2 = require("hardhat/config");
const functions_toolkit_2 = require("@chainlink/functions-toolkit");
const CNetworks_2 = __importDefault(require("../../constants/CNetworks"));
const viem_1 = require("viem");
// run with: bunx hardhat clf-sub-fund --amount 0.01 --subid 5810 --network avalancheFuji
(0, config_2.task)("clf-sub-fund", "Funds a billing subscription for Functions consumer contracts")
    .addParam("amount", "Amount to fund subscription in LINK")
    .addParam("subid", "Subscription ID to fund")
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const { name } = hre.network;
    const subId = parseInt(taskArgs.subid, 10);
    if (!CNetworks_2.default[name])
        throw new Error(`Network ${name} not supported`);
    const signer = await hre.ethers.getSigner();
    const { linkToken, functionsRouter, confirmations, functionsSubIds } = CNetworks_2.default[name];
    if (!functionsSubIds.includes(subId.toString()))
        throw new Error(`Subscription ID ${taskArgs.subid} not present on network ${name}`);
    const txOptions = { confirmations };
    const linkAmount = taskArgs.amount;
    const juelsAmount = hre.ethers.utils.parseUnits(linkAmount, 18).toString();
    const sm = new functions_toolkit_2.SubscriptionManager({
        signer,
        linkTokenAddress: linkToken,
        functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();
    // Optional: Implement a confirmation prompt before proceeding with a transaction
    // Confirm the action with the user (commented out for brevity and example purposes)
    // const utils = require('../path/to/utils');
    // await utils.prompt(`Please confirm that you wish to fund Subscription ${subscriptionId} with ${linkAmount} LINK from your wallet.`);
    console.log(`Funding subscription ${subId} with ${linkAmount} LINK...`);
    const fundTxReceipt = await sm.fundSubscription({ juelsAmount, subscriptionId: subId, txOptions });
    console.log(`Subscription ${subId} funded with ${linkAmount} LINK in Tx: ${fundTxReceipt.transactionHash}`);
    // Fetch and log updated subscription information
    const subInfo = await sm.getSubscriptionInfo(subId);
    subInfo.balance = (0, viem_1.formatEther)(subInfo.balance) + " LINK";
    subInfo.blockedBalance = (0, viem_1.formatEther)(subInfo.blockedBalance) + " LINK";
    console.log("Updated subscription Info: ", subInfo);
});
exports.default = {};
