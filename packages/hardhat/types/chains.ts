import { CNetwork } from "./CNetwork";

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
