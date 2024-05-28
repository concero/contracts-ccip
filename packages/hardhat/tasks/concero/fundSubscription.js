"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.fundSubscription = void 0;
const viem_1 = require("viem");
const FunctionsRouter_json_1 = __importDefault(require("@chainlink/contracts/abi/v0.8/FunctionsRouter.json"));
const LinkToken_json_1 = __importDefault(require("@chainlink/contracts/abi/v0.8/LinkToken.json"));
const switchChain_1 = require("../utils/switchChain");
const viem_2 = require("viem");
const log_1 = __importDefault(require("../../utils/log"));
async function fundSubscription(selectedChains) {
    for (const chain of selectedChains) {
        const { linkToken, functionsRouter, functionsSubIds, viemChain, url, name } = chain;
        const { walletClient, publicClient } = (0, switchChain_1.getClients)(viemChain, url);
        // const contract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);
        // console.log(`Checking subscription for ${contract} on ${name}`);
        const functionsRouterContract = (0, viem_1.getContract)({
            address: functionsRouter,
            abi: FunctionsRouter_json_1.default,
            client: { public: publicClient, wallet: walletClient },
        });
        const { balance, consumers } = await functionsRouterContract.read.getSubscription([functionsSubIds[0]]);
        const minBalance = 250n * 10n ** 18n; // Set minimum balance to 250 LINK
        if (balance < minBalance) {
            const amountToFund = minBalance - balance;
            // console.log(`Funding Sub ${functionsSubIds[0]} on ${networkName} with ${formatUnits(amountToFund, 18)} LINK`);
            const linkTokenContract = (0, viem_1.getContract)({
                address: linkToken,
                abi: LinkToken_json_1.default,
                client: { public: publicClient, wallet: walletClient },
            });
            const encodedData = (0, viem_2.encodeAbiParameters)([{ type: "uint64", name: "subscriptionId" }], [functionsSubIds[0]]);
            const hash = await linkTokenContract.write.transferAndCall([functionsRouter, amountToFund, encodedData]);
            const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
            (0, log_1.default)(`Funded Sub ${functionsSubIds[0]} with ${(0, viem_1.formatUnits)(amountToFund, 18)} LINK. Tx Hash: ${hash} Gas used: ${cumulativeGasUsed.toString()}`, "fundSubscription");
        }
        // CLF consumer is currently being added in the depolyment script
        // if (!consumers.map(c => c.toLowerCase()).includes(contract.toLowerCase())) {
        //   // console.log(`Adding consumer ${contract} to Sub ${functionsSubIds[0]}`);
        //   const hash = await functionsRouterContract.write.addConsumer([functionsSubIds[0], contract.toLowerCase()]);
        //   const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
        //   console.log(
        //     `Consumer ${name}:${contract} added to Sub ${functionsSubIds[0]}. Tx Hash: ${hash} Gas used: ${cumulativeGasUsed.toString()}`,
        //   );
        // } else {
        //   console.log(`Consumer ${name}:${contract} is already subscribed to ${functionsSubIds[0]}. Skipping...`);
        // }
    }
}
exports.fundSubscription = fundSubscription;
