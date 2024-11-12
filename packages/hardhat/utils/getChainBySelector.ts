import { conceroNetworks } from "../constants";
import { CNetwork } from "../types/CNetwork";

export function getChainBySelector(selector: string): CNetwork {
  for (const chain in conceroNetworks) {
    if (conceroNetworks[chain].chainSelector === selector) {
      return conceroNetworks[chain];
    }
  }

  throw new Error(`Chain with selector ${selector} not found`);
}

export function getChainById(chainId: number): CNetwork {
  for (const chain in conceroNetworks) {
    if (conceroNetworks[chain].chainId === chainId) {
      return conceroNetworks[chain];
    }
  }

  throw new Error(`Chain with id ${chainId} not found`);
}
