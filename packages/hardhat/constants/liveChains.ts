import { CNetwork } from "../types/CNetwork";
import chains from "./cNetworks";
import { ConceroChains } from "../types/chains";

export const liveChains: CNetwork[] = [
  chains.baseSepolia,
  chains.arbitrumSepolia,
  chains.avalancheFuji,
  // chains.optimismSepolia,
  // chains.polygonAmoy,
];

// export const liveChains: CNetwork[] = [chains.polygon, chains.base, chains.arbitrum, chains.avalanche];

export const conceroChains: ConceroChains = {
  testnet: {
    parentPool: [chains.baseSepolia],
    childPool: [chains.arbitrumSepolia, chains.avalancheFuji],
    infra: [chains.arbitrumSepolia, chains.avalancheFuji, chains.baseSepolia],
  },
  mainnet: {
    parentPool: [chains.base],
    childPool: [chains.polygon, chains.arbitrum, chains.avalanche],
    infra: [chains.polygon, chains.arbitrum, chains.avalanche, chains.base],
  },
};

export const testnetChains: CNetwork[] = Array.from(
  new Set([...conceroChains.testnet.parentPool, ...conceroChains.testnet.childPool, ...conceroChains.testnet.infra]),
);

export const mainnetChains: CNetwork[] = Array.from(
  new Set([...conceroChains.mainnet.parentPool, ...conceroChains.mainnet.childPool, ...conceroChains.mainnet.infra]),
);
