import "@nomicfoundation/hardhat-chai-matchers";
import { Address } from "viem";
import { getFallbackClients } from "../../../utils";
import { conceroNetworks } from "../../../constants";

const parentPoolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("start deposit usdc to parent pool\n", async () => {
  const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  const { walletClient, publicClient } = getFallbackClients(conceroNetworks.baseSepolia);

  it("should retry withdraw from automation", async () => {
    const startDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "retryPerformWithdrawalRequest",
      address: parentPoolAddress,
      args: [],
      gas: 3_000_000n,
    });

    const { status } = await publicClient.waitForTransactionReceipt({ hash: startDepositHash });

    if (status === "reverted") {
      throw new Error(`Transaction reverted. Hash: ${startDepositHash}`);
    } else {
      console.log(`Transaction successful. Hash: ${startDepositHash}`);
    }
  }).timeout(0);
});
