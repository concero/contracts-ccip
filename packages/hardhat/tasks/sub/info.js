"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("hardhat/config");
const functions_toolkit_1 = require("@chainlink/functions-toolkit");
const CNetworks_1 = __importDefault(require("../../constants/CNetworks"));
const viem_1 = require("viem");
// run with: bunx hardhat clf-sub-info --subid 5810 --network avalancheFuji
(0, config_1.task)("clf-sub-info", "Gets the Functions billing subscription balance, owner, and list of authorized consumer contract addresses")
    .addParam("subid", "Subscription ID")
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const { name } = hre.network;
    const subscriptionId = parseInt(taskArgs.subid);
    const signer = await hre.ethers.getSigner();
    const linkTokenAddress = CNetworks_1.default[name].linkToken;
    const functionsRouterAddress = CNetworks_1.default[name].functionsRouter;
    const sm = new functions_toolkit_1.SubscriptionManager({ signer, linkTokenAddress, functionsRouterAddress });
    await sm.initialize();
    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    subInfo.balance = (0, viem_1.formatEther)(subInfo.balance) + " LINK";
    subInfo.blockedBalance = (0, viem_1.formatEther)(subInfo.blockedBalance) + " LINK";
    console.log(`\nInfo for subscription ${subscriptionId}:\n`, subInfo);
});
exports.default = {};
