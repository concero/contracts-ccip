import { Address } from "viem";
import { WalletClient } from "viem/clients/createWalletClient";
import ERC20ABI from "../../abi/ERC20.json";
import { PublicClient } from "viem/clients/createPublicClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";

export async function approve(
  erc20TokenAddress: Address,
  contractAddress: Address,
  amount: BigInt,
  walletClient: WalletClient,
  publicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema>,
) {
  const senderAddress = walletClient.account.address;
  const tokenAllowance = await publicClient.readContract({
    abi: ERC20ABI,
    functionName: "allowance",
    address: erc20TokenAddress as `0x${string}`,
    args: [senderAddress, contractAddress],
  });

  if (tokenAllowance >= amount) {
    return;
  }

  const tokenAmount = await publicClient.readContract({
    abi: ERC20ABI,
    functionName: "balanceOf",
    address: erc20TokenAddress as `0x${string}`,
    args: [senderAddress],
  });

  const tokenHash = await walletClient.writeContract({
    abi: ERC20ABI,
    functionName: "approve",
    address: erc20TokenAddress as `0x${string}`,
    args: [contractAddress, amount],
  });

  await publicClient.waitForTransactionReceipt({ hash: tokenHash });
}
