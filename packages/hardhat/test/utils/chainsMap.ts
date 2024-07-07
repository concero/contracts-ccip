import { arbitrumSepolia, baseSepolia, optimismSepolia } from "viem/chains";
import { http } from "viem";

export const chainsMap = {
  [process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA]: {
    viemChain: optimismSepolia,
    viemTransport: http(`https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA]: {
    viemChain: baseSepolia,
    viemTransport: http(`https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA]: {
    viemChain: arbitrumSepolia,
    viemTransport: http(),
  },
};
