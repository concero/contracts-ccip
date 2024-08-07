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
    childPools: CNetwork[];
    infra: CNetwork[];
  };
  mainnet: {
    parentPool: CNetwork[];
    childPools: CNetwork[];
    infra: CNetwork[];
  };
}

export const conceroChains: ConceroChains = {
  testnet: {
    parentPool: [chains.baseSepolia],
    childPools: [chains.polygonAmoy, chains.arbitrumSepolia, chains.avalancheFuji],
    infra: [chains.polygonAmoy, chains.arbitrumSepolia, chains.avalancheFuji, chains.baseSepolia],
  },
  mainnet: {
    parentPool: [chains.base],
    childPools: [chains.polygon, chains.arbitrum, chains.avalanche],
    infra: [chains.polygon, chains.arbitrum, chains.avalanche, chains.base],
  },
};
