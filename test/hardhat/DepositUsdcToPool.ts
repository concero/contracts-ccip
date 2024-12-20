import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { Address, createPublicClient, createWalletClient, PrivateKeyAccount } from "viem";
import { PublicClient } from "viem/clients/createPublicClient";
import { approve } from "./utils/approve";
import { chainsMap } from "./utils/chainsMap";

const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
const usdcAmount = "10";
const usdcTokenAddress = process.env.USDC_BASE_SEPOLIA as Address;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("deposit usdc to pool\n", async () => {
  const { abi: ParentPoolAbi } = await import("../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  let srcPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
  });

  const viemAccount: PrivateKeyAccount = privateKeyToAccount(
    ("0x" + process.env.DEPLOYER_PRIVATE_KEY) as `0x${string}`,
  );
  const walletClient: WalletClient<HttpTransport, Chain, Account, RpcSchema> = createWalletClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
    account: viemAccount,
  });

  const callApprovals = async () => {
    await approve(usdcTokenAddress, poolAddress, BigInt(usdcAmount), walletClient, srcPublicClient);
  };

  it("should deposit usdc to pool", async () => {
    try {
      await callApprovals();

      const transactionHash = await walletClient.writeContract({
        abi: ParentPoolAbi,
        functionName: "depositLiquidity",
        address: poolAddress as Address,
        args: [BigInt(usdcAmount)],
        gas: 3_000_000n,
      });

      const { status } = await srcPublicClient.waitForTransactionReceipt({ hash: transactionHash });

      console.log("transactionHash: ", transactionHash);
      console.log("status: ", status, "\n");
    } catch (error) {
      console.error("Error: ", error);
    }
  }).timeout(0);
});
