import { privateKeyToAccount } from "viem/accounts";
import { Chain, createClient, createPublicClient, createWalletClient, custom, http } from "viem";

export function getClients(viemChain: Chain, url: string) {
  const account = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);

  const publicClient = createPublicClient({ transport: http(url), chain: viemChain });
  const walletClient = createWalletClient({ transport: http(url), chain: viemChain, account });

  return { walletClient, publicClient, account };
}
