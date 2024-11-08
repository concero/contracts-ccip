import { cNetworks } from "../constants";
import { CNetwork } from "../types/CNetwork";

export function getChainBySelector(selector: string): CNetwork {
  for (const chain in cNetworks) {
    if (cNetworks[chain].chainSelector === selector) {
      return cNetworks[chain];
    }
  }

  throw new Error(`Chain with selector ${selector} not found`);
}

export function getChainById(chainId: number): CNetwork {
  for (const chain in cNetworks) {
    if (cNetworks[chain].chainId === chainId) {
      return cNetworks[chain];
    }
  }

  throw new Error(`Chain with id ${chainId} not found`);
}
