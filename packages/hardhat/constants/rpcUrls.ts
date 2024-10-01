const { INFURA_API_KEY, ALCHEMY_API_KEY, BLAST_API_KEY, CHAINSTACK_API_KEY, TENDERLY_API_KEY } = process.env;

export const rpc: Record<string, string> = {
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

// Warning: ANKR endpoints are limited to 30 requests/sec and not suitable for production use

export const urls: Record<string, string[]> = {
  mainnet: [
    `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
    `https://eth-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/eth",
  ],
  sepolia: [
    `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://eth-sepolia.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/eth_sepolia",
  ],
  avalanche: [
    `https://ava-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/avalanche",
    `https://avalanche-mainnet.infura.io/v3/${INFURA_API_KEY}`,
  ],
  avalancheFuji: [
    "https://rpc.ankr.com/avalanche_fuji",
    `https://avalanche-fuji.infura.io/v3/${INFURA_API_KEY}`,
    `https://avalanche-fuji.core.chainstack.com/ext/bc/C/rpc/${CHAINSTACK_API_KEY}`,
    `https://ava-testnet.blastapi.io/${BLAST_API_KEY}`,
  ],
  arbitrum: [
    `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    `https://arbitrum-one.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/arbitrum",
  ],
  arbitrumSepolia: [
    `https://arbitrum-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://arbitrum-sepolia.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/arbitrum_sepolia",
  ],
  optimism: [
    `https://optimism-mainnet.infura.io/v3/${INFURA_API_KEY}`,
    `https://optimism-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/optimism",
  ],
  optimismSepolia: [
    `https://optimism-sepolia.infura.io/v3/${INFURA_API_KEY}`,
    `https://optimism-sepolia.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/optimism_sepolia",
  ],
  polygon: [
    `https://polygon.gateway.tenderly.co/${TENDERLY_API_KEY}`,
    `https://polygon-mainnet.blastapi.io/${BLAST_API_KEY}`,
    "https://rpc.ankr.com/polygon",
    "https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}",
    "https://polygon-bor-rpc.publicnode.com",
  ],
  polygonAmoy: [
    "https://rpc.ankr.com/polygon_amoy",
    `https://polygon-amoy.blastapi.io/${BLAST_API_KEY}`,
    `https://polygon-amoy.infura.io/v3/${INFURA_API_KEY}`,
  ],
  base: [
    "https://rpc.ankr.com/base",
    `https://base-rpc.publicnode.com`,
    `https://base-mainnet.blastapi.io/${BLAST_API_KEY}`,
  ],
  baseSepolia: [
    `https://base-sepolia.g.alchemy.com/v2/${ALCHEMY_API_KEY}`,
    "https://rpc.ankr.com/base_sepolia",
    `https://base-sepolia.blastapi.io/${BLAST_API_KEY}`,
  ],
  bsc: ["https://rpc.ankr.com/bsc"],
  scroll: ["https://rpc.ankr.com/scroll"],
  scrollSepolia: ["https://rpc.ankr.com/scroll_sepolia"],
  polygonZkEvm: [`https://polygon-zkevm-mainnet.blastapi.io/${BLAST_API_KEY}`],
  polygonZkEvmCardona: [`https://polygon-zkevm-cardona.blastapi.io/${BLAST_API_KEY}`],
};

export default rpc;
