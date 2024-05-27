"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const CNetworks_1 = __importDefault(require("../../../constants/CNetworks"));
const config_1 = require("hardhat/config");
(0, config_1.task)("clf-set-donid", "Updates the oracle address for a FunctionsConsumer consumer contract using the FunctionsOracle address from `network-config.js`")
    .addParam("contract", "Address of the consumer contract to update")
    .setAction(async (taskArgs) => {
    const { name } = hre.network;
    const donId = CNetworks_1.default[name].functionsDonId;
    console.log(`Setting donId to ${donId} in Functions consumer contract ${taskArgs.contract} on ${name}`);
    const consumerContractFactory = await hre.ethers.getContractFactory("FunctionsConsumer");
    const consumerContract = await consumerContractFactory.attach(taskArgs.contract);
    const donIdBytes32 = hre.ethers.utils.formatBytes32String(donId);
    const updateTx = await consumerContract.setDonId(donIdBytes32);
    console.log(`\nWaiting ${CNetworks_1.default[name].confirmations} blocks for transaction ${updateTx.hash} to be confirmed...`);
    await updateTx.wait(CNetworks_1.default[name].confirmations);
    console.log(`\nUpdated donId to ${donId} for Functions consumer contract ${taskArgs.contract} on ${name}`);
});
exports.default = {};
