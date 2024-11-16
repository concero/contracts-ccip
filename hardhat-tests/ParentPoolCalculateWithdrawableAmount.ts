import "@nomicfoundation/hardhat-chai-matchers";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { Address, createPublicClient } from "viem";
import { PublicClient } from "viem/clients/createPublicClient";
import { chainsMap } from "./utils/chainsMap";

const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("calculate withdrawable amount from pools\n", async () => {
  const { abi: ParentPoolAbi } = await import("../artifacts/contracts/ParentPool.sol/ParentPool.json");

  const publicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
  });

  it("calculate withdrawable amount from pools", async () => {
    const usdcAmount = await publicClient.readContract({
      abi: ParentPoolAbi,
      functionName: "calculateWithdrawableAmount",
      address: poolAddress,
      args: [10000000n, 1000000000000000000n],
    });

    console.log("usdcAmount: ", usdcAmount);
  }).timeout(0);
});
