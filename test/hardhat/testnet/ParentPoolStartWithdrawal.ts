import "@nomicfoundation/hardhat-chai-matchers";
import { Address, parseUnits } from "viem";
import { approve } from "../utils/approve";
import { getFallbackClients } from "../../../utils";
import { conceroNetworks } from "../../../constants";

const fromChain = conceroNetworks.baseSepolia;
const lpAmount = parseUnits("5", 18);
const lpTokenAddress = process.env.LPTOKEN_BASE_SEPOLIA;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA;

describe("start withdrawal usdc from parent pool\n", async () => {
  const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  const { walletClient, publicClient } = getFallbackClients(fromChain);

  it("should start withdraw usdc from pool", async () => {
    await approve(lpTokenAddress, poolAddress, lpAmount, walletClient, publicClient);

    const startWithdrawalHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "startWithdrawal",
      address: poolAddress as Address,
      args: [lpAmount],
      gas: 3_000_000n,
    });

    const { status } = await publicClient.waitForTransactionReceipt({ hash: startWithdrawalHash });

    if (status === "reverted") {
      throw new Error(`Transaction reverted. hash: ${startWithdrawalHash}`);
    } else {
      console.log(`Transaction successful. hash: ${startWithdrawalHash}`);
    }
  }).timeout(0);
});
