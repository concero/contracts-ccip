import chains from "../constants/CNetworks";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, http } from "viem";

export function getClients(networkName) {
  const { url, viemChain } = chains[networkName];
  const account = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
  const walletClient = createWalletClient({ transport: http(url), chain: viemChain, account });
  const publicClient = createPublicClient({ transport: http(url), chain: viemChain });
  return { walletClient, publicClient };
}
