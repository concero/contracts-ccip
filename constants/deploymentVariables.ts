import { getEnvVar } from "../utils";
import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt";
import { WriteContractParameters } from "viem";
import { EnvPrefixes } from "../types/deploymentVariables";

export const messengers: string[] = [
  getEnvVar("MESSENGER_0_ADDRESS"),
  getEnvVar("MESSENGER_1_ADDRESS"),
  getEnvVar("MESSENGER_2_ADDRESS"),
];
export const poolMessengers: string[] = [
  getEnvVar("POOL_MESSENGER_0_ADDRESS"),
  getEnvVar("POOL_MESSENGER_0_ADDRESS"),
  getEnvVar("POOL_MESSENGER_0_ADDRESS"),
];

export const viemReceiptConfig: WaitForTransactionReceiptParameters = {
  timeout: 0,
  confirmations: 2,
};
export const writeContractConfig: WriteContractParameters = {
  gas: 3000000n, // 3M
};
export enum ProxyEnum {
  infraProxy = "infraProxy",
  parentPoolProxy = "parentPoolProxy",
  childPoolProxy = "childPoolProxy",
}

export const envPrefixes: EnvPrefixes = {
  infraProxy: "CONCERO_INFRA_PROXY",
  infraProxyAdmin: "CONCERO_INFRA_PROXY_ADMIN",
  bridge: "CONCERO_BRIDGE",
  dexSwap: "CONCERO_DEX_SWAP",
  orchestrator: "CONCERO_ORCHESTRATOR",
  parentPoolProxy: "PARENT_POOL_PROXY",
  parentPoolProxyAdmin: "PARENT_POOL_PROXY_ADMIN",
  parentPool: "PARENT_POOL",
  childPoolProxy: "CHILD_POOL_PROXY",
  childPoolProxyAdmin: "CHILD_POOL_PROXY_ADMIN",
  childPool: "CHILD_POOL",
  automation: "CONCERO_AUTOMATION",
  lpToken: "LPTOKEN",
  create3Factory: "CREATE3_FACTORY",
  pause: "CONCERO_PAUSE",
  uniswapRouter: "UNISWAP_ROUTER",
  poolMessenger0: "POOL_MESSENGER_0_ADDRESS",
  poolMessenger1: "POOL_MESSENGER_1_ADDRESS",
  poolMessenger2: "POOL_MESSENGER_2_ADDRESS",
  infraMessenger0: "MESSENGER_0_ADDRESS",
  infraMessenger1: "MESSENGER_1_ADDRESS",
  infraMessenger2: "MESSENGER_2_ADDRESS",
};
