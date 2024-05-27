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
const config_1 = require("hardhat/config");
const deployInfra_1 = require("./deployInfra");
const CNetworks_1 = __importStar(require("../../constants/CNetworks"));
const getEnvVar_1 = require("../../utils/getEnvVar");
const switchChain_1 = require("../utils/switchChain");
const load_1 = __importDefault(require("../../utils/load"));
const getHashSum_1 = __importDefault(require("../../utils/getHashSum"));
const CLFSecrets_1 = __importDefault(require("../../constants/CLFSecrets"));
const log_1 = __importDefault(require("../../utils/log"));
async function updateHashes(chain) {
    const { name, url, viemChain } = chain;
    try {
        const contract = (0, getEnvVar_1.getEnvVar)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[name]}`);
        const { walletClient, publicClient, account } = (0, switchChain_1.getClients)(viemChain, url);
        const { abi } = await (0, load_1.default)("../artifacts/contracts/Concero.sol/Concero.json");
        // todo: make public variables for this to work
        // const result = await publicClient.readContract({
        //   address: contract,
        //   abi,
        //   functionName: "JsCodeHashSum",
        //   account,
        //   chain: viemChain,
        // });
        //
        // if (result.status === "success") {
        //   console.log(`Read Hash of the contract on ${name}: ${result.result}`);
        // }
        const srcHash = (0, getHashSum_1.default)(CLFSecrets_1.default.SRC_JS);
        const dstHash = (0, getHashSum_1.default)(CLFSecrets_1.default.DST_JS);
        const { request: updateHashReq } = await publicClient.simulateContract({
            address: contract,
            abi,
            functionName: "setSrcJsHashSum",
            account,
            chain: viemChain,
            args: [srcHash],
        });
        const updateHashRes = await walletClient.writeContract(updateHashReq);
        const { cumulativeGasUsed: updateHashGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: updateHashRes,
        });
        (0, log_1.default)(`Set ${name}:${contract} setSrcJsHashSum[${srcHash}] Gas used: ${updateHashGasUsed.toString()}`, "update-hashes");
        const { request: updateDstHashReq } = await publicClient.simulateContract({
            address: contract,
            abi,
            functionName: "setDstJsHashSum",
            account,
            chain: viemChain,
            args: [dstHash],
        });
        const updateDstHashRes = await walletClient.writeContract(updateDstHashReq);
        const { cumulativeGasUsed: updateDstHashGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: updateDstHashRes,
        });
        (0, log_1.default)(`Set ${name}:${contract} setDstJsHashSum[${dstHash}] Gas used: ${updateDstHashGasUsed.toString()}`, "update-hashes");
    }
    catch (error) {
        (0, log_1.default)(`Error for ${name}: ${error.message}`, "update-hashes");
    }
}
(0, config_1.task)("clf-update-hashes", "Update the hashes of the contracts")
    .addFlag("all", "Update all contracts")
    .setAction(async (taskArgs, hre) => {
    if (taskArgs.all) {
        for (const liveChain of deployInfra_1.liveChains) {
            await updateHashes(liveChain);
        }
    }
    const { name } = hre.network;
    await updateHashes(CNetworks_1.default[name]);
});
exports.default = {};
