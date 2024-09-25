import "@nomicfoundation/hardhat-chai-matchers";
import { Address } from "viem";
import { abi as ParentPoolAbi } from "../../artifacts/contracts/ParentPool.sol/ParentPool.json";
import { getFallbackClients } from "../../utils";
import { cNetworks } from "../../constants";

const parentPoolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("start deposit usdc to parent pool\n", () => {
  const { walletClient, publicClient } = getFallbackClients(cNetworks.baseSepolia);

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
