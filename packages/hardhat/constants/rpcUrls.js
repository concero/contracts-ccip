"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const { INFURA_API_KEY } = process.env;
const rpc = {
    arbitrum: `https://arbitrum-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    arbitrumSepolia: `https://arbitrum-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    base: `https://base-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    baseSepolia: `https://base-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    avalanche: `https://avalanche-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    avalancheFuji: `https://avalanche-fuji.infura.io/v3/${INFURA_API_KEY}`,
    mainnet: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
    sepolia: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
    optimism: `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    optimismSepolia: `https://optimism-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    polygon: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    polygonAmoy: `https://polygon-amoy.infura.io/v3/${INFURA_API_KEY}`,
};
exports.default = rpc;
