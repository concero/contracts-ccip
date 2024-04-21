import chains from "../constants/CNetworks";
import { privateKeyToAccount } from "viem/accounts";
import { Chain, createPublicClient, createWalletClient, http } from "viem";

export function getClients(viemChain: Chain, url: string) {
  const account = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
  const walletClient = createWalletClient({ transport: http(url), chain: viemChain, account });
  const publicClient = createPublicClient({ transport: http(url), chain: viemChain });
  return { walletClient, publicClient, account };
}
