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
