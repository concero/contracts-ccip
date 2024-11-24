import { CNetworkNames } from "../types/CNetwork";

export const clfFees: Record<CNetworkNames, bigint> = {
  polygon: 33131965864723535n,
  arbitrum: 20000000000000000n,
  base: 60000000000000000n,
  avalanche: 240000000000000000n,
};

export const defaultCLFfee = 20000000000000000n;
