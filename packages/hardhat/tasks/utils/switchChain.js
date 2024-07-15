"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getClients = void 0;
const accounts_1 = require("viem/accounts");
const viem_1 = require("viem");
function getClients(viemChain, url, account = (0, accounts_1.privateKeyToAccount)(`0x${process.env.DEPLOYER_PRIVATE_KEY}`)) {
    const publicClient = (0, viem_1.createPublicClient)({ transport: (0, viem_1.http)(url), chain: viemChain });
    const walletClient = (0, viem_1.createWalletClient)({ transport: (0, viem_1.http)(url), chain: viemChain, account });
    return { walletClient, publicClient, account };
}
exports.getClients = getClients;
