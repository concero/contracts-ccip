"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("@nomicfoundation/hardhat-chai-matchers");
const accounts_1 = require("viem/accounts");
const viem_1 = require("viem");
const chains_1 = require("viem/chains");
const ERC20_json_1 = __importDefault(require("../../abi/ERC20.json"));
const Concero_json_1 = require("../../artifacts/contracts/Concero.sol/Concero.json");
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
const chainsMap = {
    [process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA]: {
        viemChain: chains_1.optimismSepolia,
        viemTransport: (0, viem_1.http)(`https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
    },
    [process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA]: {
        viemChain: chains_1.baseSepolia,
        viemTransport: (0, viem_1.http)(`https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`),
    },
    [process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA]: {
        viemChain: chains_1.arbitrumSepolia,
        viemTransport: (0, viem_1.http)(),
    },
};
const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA;
const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
const senderAddress = process.env.TESTS_WALLET_ADDRESS;
const amount = "3000000000000000000";
const bnmTokenAddress = process.env.CCIPBNM_ARBITRUM_SEPOLIA;
// const linkTokenAddress = process.env.LINK_BASE_SEPOLIA;
const transactionsCount = 1;
const srcContractAddress = process.env.CONCEROCCIP_ARBITRUM_SEPOLIA;
const dstContractAddress = process.env.CONCEROCCIP_BASE_SEPOLIA;
describe("startBatchTransactions\n", () => {
    let Concero;
    let srcPublicClient = (0, viem_1.createPublicClient)({
        chain: chainsMap[srcChainSelector].viemChain,
        transport: chainsMap[srcChainSelector].viemTransport,
    });
    let dstPublicClient = (0, viem_1.createPublicClient)({
        chain: chainsMap[dstChainSelector].viemChain,
        transport: chainsMap[dstChainSelector].viemTransport,
    });
    let viemAccount = (0, accounts_1.privateKeyToAccount)(("0x" + process.env.TESTS_WALLET_PRIVATE_KEY));
    let nonce;
    let walletClient = (0, viem_1.createWalletClient)({
        chain: chainsMap[srcChainSelector].viemChain,
        transport: chainsMap[srcChainSelector].viemTransport,
        account: viemAccount,
    });
    before(async () => {
        nonce = BigInt(await srcPublicClient.getTransactionCount({
            address: viemAccount.address,
        }));
    });
    const approveBnmAndLink = async () => {
        const approveToken = async (tokenAddress) => {
            const tokenAmount = await srcPublicClient.readContract({
                abi: ERC20_json_1.default,
                functionName: "balanceOf",
                address: tokenAddress,
                args: [senderAddress],
            });
            const tokenHash = await walletClient.writeContract({
                abi: ERC20_json_1.default,
                functionName: "approve",
                address: tokenAddress,
                args: [srcContractAddress, BigInt(tokenAmount)],
                nonce: nonce++,
            });
            console.log("tokenApprovalHash: ", tokenHash);
            return tokenHash;
        };
        const bnmHash = await approveToken(bnmTokenAddress);
        // const linkHash = await approveToken(linkTokenAddress);
        await Promise.all([
            srcPublicClient.waitForTransactionReceipt({ hash: bnmHash }),
            // srcPublicClient.waitForTransactionReceipt({ hash: linkHash }),
        ]);
    };
    const checkTransactionStatus = async (transactionHash, fromSrcBlockNumber, fromDstBlock) => {
        await srcPublicClient.waitForTransactionReceipt({ hash: transactionHash });
        const getLog = async (id, eventName, contractAddress, viemPublicClient, fromBlock) => {
            const logs = await viemPublicClient.getLogs({
                address: contractAddress,
                abi: Concero_json_1.abi,
                fromBlock: fromBlock,
                toBlock: "latest",
            });
            const filteredLog = logs.find((log) => {
                const decodedLog = (0, viem_1.decodeEventLog)({
                    abi: Concero_json_1.abi,
                    data: log.data,
                    topics: log.topics,
                });
                const logId = eventName === "CCIPSent" ? log.transactionHash : decodedLog.args.ccipMessageId;
                return logId?.toLowerCase() === id.toLowerCase() && decodedLog.eventName === eventName;
            });
            if (!filteredLog) {
                return null;
            }
            return (0, viem_1.decodeEventLog)({
                abi: Concero_json_1.abi,
                data: filteredLog.data,
                topics: filteredLog.topics,
            });
        };
        const ccipMessageId = (await getLog(transactionHash, "CCIPSent", srcContractAddress, srcPublicClient, fromSrcBlockNumber)).args.ccipMessageId;
        console.log("ccipMessageId: ", ccipMessageId);
        let dstLog = null;
        while (dstLog === null) {
            dstLog = await getLog(ccipMessageId, "TXReleased", dstContractAddress, dstPublicClient, fromDstBlock);
            if (dstLog) {
                console.log("dstLogs: ", dstLog);
            }
            await sleep(5000);
        }
        return dstLog;
    };
    it("should start transactions", async () => {
        await approveBnmAndLink();
        const fromSrcBlockNumber = await srcPublicClient.getBlockNumber();
        const fromDstBlockNumber = await dstPublicClient.getBlockNumber();
        let transactionPromises = [];
        for (let i = 0; i < transactionsCount; i++) {
            const { request } = await srcPublicClient.simulateContract({
                abi: Concero_json_1.abi,
                functionName: "startTransaction",
                address: srcContractAddress,
                args: [bnmTokenAddress, 0, BigInt(amount), BigInt(dstChainSelector), senderAddress],
                account: viemAccount,
                // value,
                nonce: nonce++,
            });
            transactionPromises.push(walletClient.writeContract(request));
        }
        const transactionHashes = await Promise.all(transactionPromises);
        console.log("transactionHashes: ", transactionHashes);
        const txStatusPromises = transactionHashes.map(txHash => {
            return checkTransactionStatus(txHash, "0x" + fromSrcBlockNumber.toString(16), "0x" + fromDstBlockNumber.toString(16));
        });
        const txStatuses = await Promise.all(txStatusPromises);
        console.log("txStatuses: ", txStatuses);
    }).timeout(0);
});
