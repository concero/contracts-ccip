import { privateKeyToAccount } from "viem/accounts";
import { Chain, createPublicClient, createWalletClient, http } from "viem";
import type { PrivateKeyAccount } from "viem/accounts/types";

export function getClients(
  viemChain: Chain,
  url: string | undefined,
  account?: PrivateKeyAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`),
) {
  const publicClient = createPublicClient({ transport: http(url), chain: viemChain });
  const walletClient = createWalletClient({ transport: http(url), chain: viemChain, account });

  return { walletClient, publicClient, account };
}
