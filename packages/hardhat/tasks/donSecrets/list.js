"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const functions_toolkit_1 = require("@chainlink/functions-toolkit");
const CNetworks_1 = __importDefault(require("../../constants/CNetworks"));
const config_1 = require("hardhat/config");
const deployInfra_1 = require("../concero/deployInfra");
const getEthersSignerAndProvider_1 = require("../utils/getEthersSignerAndProvider");
const log_1 = __importDefault(require("../../utils/log"));
async function listSecrets(chain) {
    const { provider, signer } = (0, getEthersSignerAndProvider_1.getEthersSignerAndProvider)(chain.url);
    const { functionsRouter, functionsDonIdAlias, functionsGatewayUrls } = chain;
    if (!functionsGatewayUrls || functionsGatewayUrls.length === 0)
        throw Error(`No gatewayUrls found for ${chain.name}.`);
    const secretsManager = new functions_toolkit_1.SecretsManager({
        signer,
        functionsRouterAddress: functionsRouter,
        donId: functionsDonIdAlias,
    });
    await secretsManager.initialize();
    const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
    const allSecrets = {};
    result.nodeResponses.forEach(nodeResponse => {
        if (nodeResponse.rows) {
            nodeResponse.rows.forEach(row => {
                if (allSecrets[row.slot_id] && allSecrets[row.slot_id].version !== row.version)
                    return (0, log_1.default)(`Node mismatch for slot_id. ${allSecrets[row.slot_id]} !== ${row.slot_id}!`, "listSecrets");
                allSecrets[row.slot_id] = { version: row.version, expiration: row.expiration };
            });
        }
        // else {
        //   // updateEnvVariable(`CLF_DON_SECRETS_VERSION_${networkEnvKeys[chain.name]}`, "0", "../../../.env.clf");
        // }
    });
    (0, log_1.default)(`DON secrets for ${chain.name}:`, "listSecrets");
    console.log(allSecrets);
    return allSecrets;
}
// run with: yarn hardhat clf-donsecrets-list --network avalancheFuji
(0, config_1.task)("clf-donsecrets-list", "Displays encrypted secrets hosted on the DON")
    .addFlag("all", "List secrets from all chains")
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const { all } = taskArgs;
    if (all) {
        for (const chain of deployInfra_1.liveChains) {
            console.log(`\nListing secrets for ${chain.name}`);
            await listSecrets(chain);
        }
    }
    else {
        const { name } = hre.network;
        await listSecrets(CNetworks_1.default[name]);
    }
});
exports.default = listSecrets;
