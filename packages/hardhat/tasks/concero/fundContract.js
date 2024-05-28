"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.fundContract = exports.ensureDeployerBnMBalance = void 0;
const IERC20_json_1 = __importDefault(require("@chainlink/contracts/abi/v0.8/IERC20.json"));
const switchChain_1 = require("../utils/switchChain");
const CNetworks_1 = require("../../constants/CNetworks");
const dripBnm_1 = require("./dripBnm");
const config_1 = require("hardhat/config");
const deployInfra_1 = require("./deployInfra");
const CNetworks_2 = __importDefault(require("../../constants/CNetworks"));
const getEnvVar_1 = require("../../utils/getEnvVar");
const log_1 = __importDefault(require("../../utils/log"));
async function ensureDeployerBnMBalance(chains) {
    //checks balance of CCIPBnm of deployer
    for (const chain of chains) {
        const { ccipBnmToken, viemChain, url, name } = chain;
        const { publicClient, account } = (0, switchChain_1.getClients)(viemChain, url);
        const balance = await publicClient.readContract({
            address: ccipBnmToken,
            abi: IERC20_json_1.default,
            functionName: "balanceOf",
            args: [account.address],
        });
        if (balance < 5n * 10n ** 18n) {
            (0, log_1.default)(`Deployer ${name}:${account.address} has insufficient CCIPBNM balance. Dripping...`, "ensureDeployerBnMBalance");
            await (0, dripBnm_1.dripBnm)([chain], 5);
        }
    }
}
exports.ensureDeployerBnMBalance = ensureDeployerBnMBalance;
async function fundContract(chains, amount = 1) {
    try {
        for (const chain of chains) {
            const { name, viemChain, ccipBnmToken, url } = chain;
            const contract = (0, getEnvVar_1.getEnvVar)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[name]}`);
            const { walletClient, publicClient, account } = (0, switchChain_1.getClients)(viemChain, url);
            await ensureDeployerBnMBalance(chains);
            const { request: sendReq } = await publicClient.simulateContract({
                functionName: "transfer",
                abi: IERC20_json_1.default,
                account,
                address: ccipBnmToken,
                args: [contract, BigInt(amount) * 10n ** 18n],
            });
            const sendHash = await walletClient.writeContract(sendReq);
            const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({ hash: sendHash });
            (0, log_1.default)(`Sent ${amount} CCIPBNM to ${name}:${contract}. Gas used: ${sendGasUsed.toString()}`, "fundContract");
        }
    }
    catch (error) {
        (0, log_1.default)(`Error for ${name}: ${error.message}`, "fundContract");
    }
}
exports.fundContract = fundContract;
(0, config_1.task)("fund-contracts", "Funds the contract with CCIPBNM tokens")
    .addOptionalParam("amount", "Amount of CCIPBNM to send", "5")
    .setAction(async (taskArgs) => {
    const { name } = hre.network;
    const amount = parseInt(taskArgs.amount, 10);
    if (name !== "localhost" && name !== "hardhat") {
        await fundContract([CNetworks_2.default[name]], amount);
    }
    else {
        for (const chain of deployInfra_1.liveChains) {
            await fundContract([chain], amount);
        }
    }
});
exports.default = {};
