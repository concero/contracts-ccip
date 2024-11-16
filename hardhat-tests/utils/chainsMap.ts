import { arbitrumSepolia, base, baseSepolia, optimismSepolia, polygon } from "viem/chains";
import { http } from "viem";

//todo move to cnetworks
export const chainsMap = {
  [process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA]: {
    viemChain: optimismSepolia,
    viemTransport: http(`https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA]: {
    viemChain: baseSepolia,
    viemTransport: http(`https://base-rpc.publicnode.com`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA]: {
    viemChain: arbitrumSepolia,
    viemTransport: http(),
  },
  // mainnets
  [process.env.CL_CCIP_CHAIN_SELECTOR_BASE]: {
    viemChain: base,
    viemTransport: http(),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON]: {
    viemChain: polygon,
    viemTransport: http(),
  },
};
