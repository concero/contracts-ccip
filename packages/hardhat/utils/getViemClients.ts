import { privateKeyToAccount } from "viem/accounts";
import { Chain, createPublicClient, createWalletClient, fallback, http } from "viem";
import type { PrivateKeyAccount } from "viem/accounts/types";
import { WalletClient } from "viem/clients/createWalletClient";
import { PublicClient } from "viem/clients/createPublicClient";
import { urls } from "../constants/rpcUrls";
import { CNetwork } from "../types/CNetwork";

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

export function getFallbackClients(
  chain: CNetwork,
  account?: PrivateKeyAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`),
): {
  walletClient: WalletClient;
  publicClient: PublicClient;
  account: PrivateKeyAccount;
} {
  const { viemChain, name } = chain;
  const transport = fallback(urls[name].map(url => http(url)));

  const publicClient = createPublicClient({ transport, chain: viemChain });
  const walletClient = createWalletClient({ transport, chain: viemChain, account });

  return { walletClient, publicClient, account };
}
