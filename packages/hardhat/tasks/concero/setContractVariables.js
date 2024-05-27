"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.setDonHostedSecretsVersion = exports.setContractVariables = void 0;
const CNetworks_1 = require("../../constants/CNetworks");
const switchChain_1 = require("../utils/switchChain");
const load_1 = __importDefault(require("../../utils/load"));
const getEnvVar_1 = require("../../utils/getEnvVar");
const log_1 = __importDefault(require("../../utils/log"));
const getEthersSignerAndProvider_1 = require("../utils/getEthersSignerAndProvider");
const functions_toolkit_1 = require("@chainlink/functions-toolkit");
async function setContractVariables(liveChains, deployableChains, slotId) {
    const { abi } = await (0, load_1.default)("../artifacts/contracts/Concero.sol/Concero.json");
    for (const chain of liveChains) {
        const { viemChain, url, name } = chain;
        try {
            const contract = (0, getEnvVar_1.getEnvVar)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[name]}`);
            const { walletClient, publicClient, account } = (0, switchChain_1.getClients)(viemChain, url);
            // set dstChain contracts for each contract
            for (const dstChain of liveChains) {
                const { name: dstName, chainSelector: dstChainSelector } = dstChain;
                if (dstName !== name) {
                    const dstContract = (0, getEnvVar_1.getEnvVar)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[dstName]}`);
                    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
                        address: contract,
                        abi,
                        functionName: "setConceroContract",
                        account,
                        args: [dstChainSelector, dstContract],
                        chain: viemChain,
                    });
                    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
                    const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
                        hash: setDstConceroContractHash,
                    });
                    (0, log_1.default)(`Set ${name}:${contract} dstConceroContract[${dstName}, ${dstContract}]. Gas used: ${setDstConceroContractGasUsed.toString()}`, "setContractVariables");
                }
            }
        }
        catch (error) {
            (0, log_1.default)(`Error for ${name}: ${error.message}`, "setContractVariables");
        }
    }
    for (const deployableChain of deployableChains) {
        await setDonHostedSecretsVersion(deployableChain, slotId, abi);
        await addMessengerToAllowlist(deployableChain, abi);
    }
}
exports.setContractVariables = setContractVariables;
async function setDonHostedSecretsVersion(deployableChain, slotId, abi) {
    // todo: assert slotid = current slotid in the contract, otherwise skip setDonHostedSecretsVersion
    //todo: Set DonHostedSecrets slotId in case necessary
    const { functionsRouter: dcFunctionsRouter, functionsDonIdAlias: dcFunctionsDonIdAlias, functionsGatewayUrls: dcFunctionsGatewayUrls, url: dcUrl, viemChain: dcViemChain, name: dcName, } = deployableChain;
    try {
        const dcContract = (0, getEnvVar_1.getEnvVar)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[dcName]}`);
        const { walletClient, publicClient, account } = (0, switchChain_1.getClients)(dcViemChain, dcUrl);
        // // fetch slotId from contract
        // const slotIdHash = await publicClient.readContract({
        //   address: dcContract,
        //   abi,
        //   functionName: "slotId",
        //   account,
        //   chain: dcViemChain,
        // });
        const { signer: dcSigner } = (0, getEthersSignerAndProvider_1.getEthersSignerAndProvider)(dcUrl);
        // set DONSecrets version
        const secretsManager = new functions_toolkit_1.SecretsManager({
            signer: dcSigner,
            functionsRouterAddress: dcFunctionsRouter,
            donId: dcFunctionsDonIdAlias,
        });
        await secretsManager.initialize();
        const { result } = await secretsManager.listDONHostedEncryptedSecrets(dcFunctionsGatewayUrls);
        const nodeResponse = result.nodeResponses[0];
        if (!nodeResponse.rows)
            return (0, log_1.default)(`No secrets found for ${dcName}.`, "updateContract");
        const rowBySlotId = nodeResponse.rows.find(row => row.slot_id === slotId);
        if (!rowBySlotId)
            return (0, log_1.default)(`No secrets found for ${dcName} at slot ${slotId}.`, "updateContract");
        const { request: setDstConceroContractReq } = await publicClient.simulateContract({
            address: dcContract,
            abi,
            functionName: "setDonHostedSecretsVersion",
            account,
            args: [rowBySlotId.version],
            chain: dcViemChain,
        });
        const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
        const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: setDstConceroContractHash,
        });
        (0, log_1.default)(`Set ${dcName}:${dcContract} donHostedSecretsVersion[${rowBySlotId.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`, "setContractVariables");
    }
    catch (error) {
        (0, log_1.default)(`Error for ${dcName}: ${error.message}`, "setContractVariables");
    }
}
exports.setDonHostedSecretsVersion = setDonHostedSecretsVersion;
async function addMessengerToAllowlist(deployableChain, abi) {
    const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
    const { walletClient, publicClient, account } = (0, switchChain_1.getClients)(dcViemChain, dcUrl);
    try {
        const dcContract = (0, getEnvVar_1.getEnvVar)(`CONCEROCCIP_${CNetworks_1.networkEnvKeys[dcName]}`);
        const messengerWallet = (0, getEnvVar_1.getEnvVar)("MESSENGER_WALLET_ADDRESS");
        const { request: addToAllowlistReq } = await publicClient.simulateContract({
            address: dcContract,
            abi,
            functionName: "setConceroMessenger",
            account,
            args: [messengerWallet],
            chain: dcViemChain,
        });
        const addToAllowlistHash = await walletClient.writeContract(addToAllowlistReq);
        const { cumulativeGasUsed: addToAllowlistGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: addToAllowlistHash,
        });
        (0, log_1.default)(`Set ${dcName}:${dcContract} allowlist[${messengerWallet}]. Gas used: ${addToAllowlistGasUsed.toString()}`, "setContractVariables");
    }
    catch (error) {
        if (error.message.includes("Address already in allowlist")) {
            (0, log_1.default)(`${messengerWallet} was already added to allowlist of ${dcContract}`, "setContractVariables");
        }
        else {
            (0, log_1.default)(`Error for ${dcName}: ${error.message}`, "setContractVariables");
        }
    }
}
//todo: add set hash
