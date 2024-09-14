import { CNetwork } from "../../types/CNetwork";
import chains from "../../constants/CNetworks";

// export const liveChains: CNetwork[] = [
//   chains.baseSepolia,
//   // chains.arbitrumSepolia,
//   // chains.avalancheFuji,
//   // chains.optimismSepolia,
//   // chains.polygonAmoy,
// ];

export const liveChains: CNetwork[] = [chains.polygon, chains.base, chains.arbitrum, chains.avalanche];

export interface ConceroChains {
  testnet: {
    parentPool: CNetwork[];
    childPool: CNetwork[];
    infra: CNetwork[];
  };
  mainnet: {
    parentPool: CNetwork[];
    childPool: CNetwork[];
    infra: CNetwork[];
  };
}

export const conceroChains: ConceroChains = {
  testnet: {
    parentPool: [chains.baseSepolia],
    childPool: [chains.polygonAmoy, chains.arbitrumSepolia, chains.avalancheFuji],
    infra: [chains.polygonAmoy, chains.arbitrumSepolia, chains.avalancheFuji, chains.baseSepolia],
  },
  mainnet: {
    parentPool: [chains.base], // 12
    childPool: [chains.polygon, chains.arbitrum, chains.avalanche], // 2
    infra: [chains.polygon, chains.arbitrum, chains.avalanche, chains.base], // 4
  },
};

export const testnetChains: CNetwork[] = Array.from(new Set([
  ...conceroChains.testnet.parentPool,
  ...conceroChains.testnet.childPool,
  ...conceroChains.testnet.infra,
]));

export const mainnetChains: CNetwork[] = Array.from(new Set([
  ...conceroChains.mainnet.parentPool,
  ...conceroChains.mainnet.childPool,
  ...conceroChains.mainnet.infra,
]));
