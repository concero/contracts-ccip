import { privateKeyToAccount } from "viem/accounts";
import { Chain, createPublicClient, createWalletClient, http } from "viem";
import type { PrivateKeyAccount } from "viem/accounts/types";
import { WalletClient } from "viem/clients/createWalletClient";
import { PublicClient } from "viem/clients/createPublicClient";

export function getClients(
  viemChain: Chain,
  url: string | undefined,
  account?: PrivateKeyAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`),
): {
  walletClient: WalletClient;
  publicClient: PublicClient;
  account: PrivateKeyAccount;
} {
  const publicClient = createPublicClient({ transport: http(url), chain: viemChain });
  const walletClient = createWalletClient({ transport: http(url), chain: viemChain, account });

  return { walletClient, publicClient, account };
}
