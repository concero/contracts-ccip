"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.dripBnm = void 0;
const switchChain_1 = require("../utils/switchChain");
const CNetworks_1 = __importDefault(require("../../constants/CNetworks"));
const deployInfra_1 = require("./deployInfra");
const config_1 = require("hardhat/config");
async function dripBnm(chains, amount = 20) {
    for (const chain of chains) {
        const { ccipBnmToken, viemChain, url, name } = chain;
        const { walletClient, publicClient, account } = (0, switchChain_1.getClients)(viemChain, url);
        const gasPrice = await publicClient.getGasPrice();
        for (let i = 0; i < amount; i++) {
            const { request: sendReq } = await publicClient.simulateContract({
                functionName: "drip",
                abi: [
                    {
                        inputs: [{ internalType: "address", name: "to", type: "address" }],
                        name: "drip",
                        outputs: [],
                        stateMutability: "nonpayable",
                        type: "function",
                    },
                ],
                account,
                address: ccipBnmToken,
                args: [account.address],
                gasPrice,
            });
            const sendHash = await walletClient.writeContract(sendReq);
            const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({ hash: sendHash });
            console.log(`Sent 1 CCIPBNM token to ${name}:${account.address}. Gas used: ${sendGasUsed.toString()}`);
        }
    }
}
exports.dripBnm = dripBnm;
(0, config_1.task)("drip-bnm", "Drips CCIPBNM tokens to the deployer")
    .addOptionalParam("amount", "Amount of CCIPBNM to drip", "5")
    .setAction(async (taskArgs) => {
    const { name } = hre.network;
    const amount = parseInt(taskArgs.amount, 10);
    if (name !== "localhost" && name !== "hardhat") {
        await dripBnm([CNetworks_1.default[name]], amount);
    }
    else {
        for (const chain of deployInfra_1.liveChains) {
            await dripBnm([chain], amount);
        }
    }
});
exports.default = {};
