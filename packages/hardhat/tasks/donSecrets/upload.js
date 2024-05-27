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
const functions_toolkit_1 = require("@chainlink/functions-toolkit");
const CNetworks_1 = __importStar(require("../../constants/CNetworks"));
const CLFSecrets_1 = __importDefault(require("../../constants/CLFSecrets"));
const updateEnvVariable_1 = __importDefault(require("../../utils/updateEnvVariable"));
const getEthersSignerAndProvider_1 = require("../utils/getEthersSignerAndProvider");
const log_1 = __importDefault(require("../../utils/log"));
const list_1 = __importDefault(require("./list"));
const setContractVariables_1 = require("../concero/setContractVariables");
const load_1 = __importDefault(require("../../utils/load"));
const deployInfra_1 = require("../concero/deployInfra");
// const path = require("path");
async function upload(chains, slotid, ttl) {
    const slotId = parseInt(slotid);
    const minutesUntilExpiration = ttl;
    for (const chain of chains) {
        const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls, url, name } = chain;
        const { signer } = await (0, getEthersSignerAndProvider_1.getEthersSignerAndProvider)(url);
        const secretsManager = new functions_toolkit_1.SecretsManager({
            signer,
            functionsRouterAddress: functionsRouter,
            donId: functionsDonIdAlias,
        });
        await secretsManager.initialize();
        // Dynamically import the config file if necessary
        // const configPath = path.isAbsolute(taskArgs.configpath) ? taskArgs.configpath : path.join(process.cwd(), taskArgs.configpath);
        // const requestConfig = await import(configPath);
        if (!CLFSecrets_1.default) {
            console.error("No secrets to upload.");
            return;
        }
        // console.log("Uploading secrets to DON for network:", name);
        const encryptedSecretsObj = await secretsManager.encryptSecrets(CLFSecrets_1.default);
        const { version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
        success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
         } = await secretsManager.uploadEncryptedSecretsToDON({
            encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
            gatewayUrls: functionsGatewayUrls,
            slotId,
            minutesUntilExpiration,
        });
        (0, log_1.default)(`DONSecrets uploaded to ${name}. slot_id: ${slotId}, version: ${version}, ttl: ${minutesUntilExpiration}`, "donSecrets/upload");
        await (0, list_1.default)(chain);
        // log(`Current DONSecrets for ${name}:`, "donSecrets/upload");
        // log(checkSecretsRes, "donSecrets/upload");
        (0, updateEnvVariable_1.default)(`CLF_DON_SECRETS_VERSION_${CNetworks_1.networkEnvKeys[name]}`, version, "../../../.env.clf");
    }
}
// run with: yarn hardhat clf-donsecrets-upload --slotid 0 --ttl 4320 --network avalancheFuji
// todo: add to deployedSecrets file with expiration time, and check if it's expired before using itV
(0, config_1.task)("clf-donsecrets-upload", "Encrypts and uploads secrets to the DON")
    .addParam("slotid", "Storage slot number 0 or higher - if the slotid is already in use, the existing secrets for that slotid will be overwritten")
    .addOptionalParam("ttl", "Time to live - minutes until the secrets hosted on the DON expire", 4320, config_1.types.int)
    .addFlag("all", "Upload secrets to all networks")
    .addFlag("updatecontracts", "Update the contracts with the new secrets")
    // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const { slotid, ttl, all, updatecontracts } = taskArgs;
    // Function to upload secrets and optionally update contracts
    const processNetwork = async (chain) => {
        await upload([chain], slotid, ttl);
        if (updatecontracts) {
            const { abi } = await (0, load_1.default)("../artifacts/contracts/Concero.sol/Concero.json");
            await (0, setContractVariables_1.setDonHostedSecretsVersion)(chain, parseInt(slotid), abi);
        }
    };
    // Process all networks if 'all' flag is set
    if (all) {
        for (const liveChain of deployInfra_1.liveChains) {
            await processNetwork(liveChain);
        }
    }
    else {
        await processNetwork(CNetworks_1.default[hre.network.name]);
    }
});
exports.default = upload;
