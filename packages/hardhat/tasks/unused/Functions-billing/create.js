"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const { SubscriptionManager } = require("@chainlink/functions-toolkit");
const CLFnetworks_1 = __importDefault(require("../../../constants/CLFnetworks"));
const chalk_1 = __importDefault(require("chalk"));
const utils = __importStar(require("../../utils"));
task("clf-sub-create", "Creates a new billing subscription for Functions consumer contracts")
    .addOptionalParam("amount", "Initial amount used to fund the subscription in LINK")
    .addOptionalParam("contract", "Address of the consumer contract address authorized to use the new billing subscription")
    .setAction(async (taskArgs) => {
    const signer = await ethers.getSigner();
    const functionsRouterAddress = CLFnetworks_1.default[network.name]["functionsRouter"];
    const linkTokenAddress = CLFnetworks_1.default[network.name]["linkToken"];
    const linkAmount = taskArgs.amount;
    const confirmations = linkAmount > 0 ? CLFnetworks_1.default[network.name].confirmations : 1;
    const consumerAddress = taskArgs.contract;
    const txOptions = {
        confirmations,
        overrides: {
            gasPrice: CLFnetworks_1.default[network.name].gasPrice,
        },
    };
    const sm = new SubscriptionManager({ signer, linkTokenAddress, functionsRouterAddress });
    await sm.initialize();
    console.log("\nCreating Functions billing subscription...");
    const subscriptionId = await sm.createSubscription({ consumerAddress, txOptions });
    console.log(`\nCreated Functions billing subscription: ${subscriptionId}`);
    // Fund subscription
    if (linkAmount) {
        await utils.prompt(`\nPlease confirm that you wish to fund Subscription ${subscriptionId} with ${chalk_1.default.blue(linkAmount + " LINK")} from your wallet.`);
        console.log(`\nFunding subscription ${subscriptionId} with ${linkAmount} LINK...`);
        const juelsAmount = ethers.utils.parseUnits(linkAmount, 18).toString();
        const fundTxReceipt = await sm.fundSubscription({ juelsAmount, subscriptionId, txOptions });
        console.log(`\nSubscription ${subscriptionId} funded with ${linkAmount} LINK in Tx: ${fundTxReceipt.transactionHash}`);
        const subInfo = await sm.getSubscriptionInfo(subscriptionId);
        // parse  balances into LINK for readability
        subInfo.balance = ethers.utils.formatEther(subInfo.balance) + " LINK";
        subInfo.blockedBalance = ethers.utils.formatEther(subInfo.blockedBalance) + " LINK";
        console.log("\nSubscription Info: ", subInfo);
    }
});
exports.default = {};
