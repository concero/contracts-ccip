import type { CNetwork } from "../../../types/CNetwork";

export interface BalanceInfo {
  chain: CNetwork;
  address: string;
  balance: string;
  target: string;
  deficit: string;
}
