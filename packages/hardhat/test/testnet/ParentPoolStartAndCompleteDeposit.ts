import "@nomicfoundation/hardhat-chai-matchers";
import { Address } from "viem";
import { abi as ParentPoolAbi } from "../../artifacts/contracts/ParentPool.sol/ParentPool.json";
import { approve } from "../utils/approve";
import { getFallbackClients } from "../../utils";
import { cNetworks } from "../../constants";

const usdcAmount = "1000000";
const usdcTokenAddress = process.env.USDC_BASE_SEPOLIA as Address;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("start deposit usdc to parent pool\n", () => {
  const { walletClient, publicClient } = getFallbackClients(cNetworks.baseSepolia);

  it("should deposit usdc to pool", async () => {
    const startDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "startDeposit",
      address: poolAddress as Address,
      args: [BigInt(usdcAmount)],
      gas: 3_000_000n,
    });

    const { status, logs } = await publicClient.waitForTransactionReceipt({ hash: startDepositHash });

    console.log("transactionHash: ", startDepositHash);

    if (status === "reverted") {
      throw new Error(`Transaction reverted`);
    } else {
      console.log("Transaction successful");
    }

    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

    await sleep(40000);
    await approve(usdcTokenAddress, poolAddress, BigInt(usdcAmount), walletClient, publicClient);

    const completeDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "completeDeposit",
      address: poolAddress as Address,
      args: [logs[0].topics[1]],
      gas: 3_000_000n,
    });

    console.log("completeDepositHash: ", completeDepositHash);

    const { status: completeDepositStatus } = await publicClient.waitForTransactionReceipt({
      hash: completeDepositHash,
    });

    console.log("completeDepositHash: ", completeDepositHash);

    if (completeDepositStatus === "reverted") {
      throw new Error(`Transaction reverted`);
    } else {
      console.log("Transaction successful");
    }
  }).timeout(0);
});
