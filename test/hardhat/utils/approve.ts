import { Address, erc20Abi, WalletClient, PublicClient, HttpTransport, Chain, Account, RpcSchema } from "viem";

export async function approve(
  erc20TokenAddress: Address,
  contractAddress: Address,
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
    address: erc20TokenAddress,
    args: [contractAddress, amount],
  });

  await publicClient.waitForTransactionReceipt({ hash: tokenHash });
}
