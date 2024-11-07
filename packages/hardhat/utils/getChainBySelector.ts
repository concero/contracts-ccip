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
