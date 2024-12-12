import { CNetworkNames } from "../types/CNetwork";

export const clfFees: Record<CNetworkNames, bigint> = {
  polygon: 36000000000000000n,
  arbitrum: 20000000000000000n,
  base: 60000000000000000n,
  avalanche: 280000000000000000n,
};

export const defaultCLFfee = 60000000000000000n;
