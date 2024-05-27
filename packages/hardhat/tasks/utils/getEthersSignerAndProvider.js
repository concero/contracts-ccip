"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getEthersSignerAndProvider = void 0;
const ethers_v5_1 = require("ethers-v5");
function getEthersSignerAndProvider(chain_url) {
    const provider = new ethers_v5_1.ethers.providers.JsonRpcProvider(chain_url);
    const signer = new ethers_v5_1.ethers.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);
    return { signer, provider };
}
exports.getEthersSignerAndProvider = getEthersSignerAndProvider;
