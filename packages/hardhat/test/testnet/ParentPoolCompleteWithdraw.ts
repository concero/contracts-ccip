import "@nomicfoundation/hardhat-chai-matchers";
import { abi as ParentPoolAbi } from "../../artifacts/contracts/ParentPool.sol/ParentPool.json";
import { getFallbackClients } from "../../utils";
import { conceroNetworks } from "../../constants";

const parentPool = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA;

describe("complete withdraw from parent pool\n", () => {
  const { walletClient, publicClient } = getFallbackClients(conceroNetworks.baseSepolia);

  it("should retry withdraw from automation", async () => {
    const startDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "completeWithdrawal",
      address: parentPool,
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
