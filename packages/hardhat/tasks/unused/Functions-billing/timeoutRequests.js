"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_2 = require("hardhat/config");
const functions_toolkit_2 = require("@chainlink/functions-toolkit");
const CNetworks_2 = __importDefault(require("../../../constants/CNetworks"));
const getEthersSignerAndProvider_1 = require("../../utils/getEthersSignerAndProvider");
(0, config_2.task)("clf-sub-timeout-requests", "Times out expired Functions requests which have not been fulfilled within 5 minutes")
    .addParam("requestids", "1 or more request IDs to timeout separated by commas")
    .addOptionalParam("toblock", "Ending search block number (defaults to latest block)")
    .addOptionalParam("pastblockstosearch", "Number of past blocks to search", 1000, config_2.types.int)
    .setAction(async (taskArgs) => {
    const hre = require("hardhat");
    const { name } = hre.network;
    if (!CNetworks_2.default[name])
        throw new Error(`Chain ${name} not supported`);
    const requestIdsToTimeout = taskArgs.requestids.split(",");
    console.log(`Timing out requests ${requestIdsToTimeout} on ${name}`);
    const toBlock = taskArgs.toblock ? Number(taskArgs.toblock) : "latest";
    const pastBlocksToSearch = parseInt(taskArgs.pastblockstosearch);
    const { signer, provider } = (0, getEthersSignerAndProvider_1.getEthersSignerAndProvider)(CNetworks_2.default[name].url);
    const { linkToken, functionsRouter, functionsDonIdAlias, confirmations } = CNetworks_2.default[name];
    // const txOptions = { overrides: { gasLimit: 10000000 } };
    const sm = new functions_toolkit_2.SubscriptionManager({
        signer,
        linkTokenAddress: linkToken,
        functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();
    const requestCommitments = [];
    for (const requestId of requestIdsToTimeout) {
        try {
            const requestCommitment = await (0, functions_toolkit_2.fetchRequestCommitment)({
                requestId,
                provider,
                functionsRouterAddress: functionsRouter,
                donId: functionsDonIdAlias,
                toBlock,
                pastBlocksToSearch,
            });
            console.log(`Fetched commitment for request ID ${requestId}`);
            if (requestCommitment.timeoutTimestamp < BigInt(Math.round(Date.now() / 1000))) {
                requestCommitments.push(requestCommitment);
            }
            else {
                console.log(`Request ID ${requestId} has not expired yet (skipping)`);
            }
        }
        catch (error) {
            console.log(`Failed to fetch commitment for request ID ${requestId} (skipping): ${error}`);
        }
    }
    if (requestCommitments.length > 0) {
        await sm.timeoutRequests({ requestCommitments });
    }
});
exports.default = {};
