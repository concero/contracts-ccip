import { getEnvVar } from "../utils/getEnvVar";
import type { WaitForTransactionReceiptParameters } from "viem/actions/public/waitForTransactionReceipt";

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
// The address is the same on 4 chains: ARB,POL,BASE,AVAX. Can be deployed to others later using Lifi's Create3 Factory.
export const initialProxyImplementationAddress = getEnvVar("CONCERO_PAUSE_ARBITRUM");

export const viemReceiptConfig: WaitForTransactionReceiptParameters = {
  timeout: 0,
  confirmations: 2,
};

export type DeploymentPrefixes = {
  infraProxy: string;
  infraProxyAdmin: string;
  bridge: string;
  dexSwap: string;
  orchestrator: string;
  parentPoolProxy: string;
  parentPoolProxyAdmin: string;
  parentPool: string;
  childPoolProxy: string;
  childPoolProxyAdmin: string;
  childPool: string;
  automation: string;
  lpToken: string;
  create3Factory: string;
  pause: string;
  uniswapRouter: string;
};

export const deploymentPrefixes: DeploymentPrefixes = {
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
};
