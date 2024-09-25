import type { CNetwork } from "../../../types/CNetwork";
import { ProxyEnum } from "../../../constants/deploymentVariables";

export interface BalanceInfo {
  chain: CNetwork;
  balance: bigint;
  donorBalance: bigint;
  deficit: bigint;
  targetBalance: bigint;
  id?: string;
  type?: ProxyEnum;
  symbol?: string;
  decimals?: number;
  address?: string;
  alias?: string;
}
