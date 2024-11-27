import { Address, erc20Abi } from "viem";
import { WalletClient } from "viem/clients/createWalletClient";
import { PublicClient } from "viem/clients/createPublicClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";

export async function approve(
  erc20TokenAddress: Address | string,
  contractAddress: Address | string,
  amount: BigInt,
  walletClient: WalletClient,
  publicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema>,
) {
  const senderAddress = walletClient.account.address;
  const tokenAllowance = await publicClient.readContract({
    abi: erc20Abi,
    functionName: "allowance",
    address: erc20TokenAddress as `0x${string}`,
    args: [senderAddress, contractAddress],
  });

  if (tokenAllowance >= amount) {
    return;
  }

  const tokenHash = await walletClient.writeContract({
    abi: erc20Abi,
    functionName: "approve",
    address: erc20TokenAddress as `0x${string}`,
    args: [contractAddress, amount],
  });

  await publicClient.waitForTransactionReceipt({ hash: tokenHash });
}
