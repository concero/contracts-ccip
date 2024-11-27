import "@nomicfoundation/hardhat-chai-matchers";
import { Address, decodeEventLog, parseUnits } from "viem";
import { approve } from "../utils/approve";
import { getFallbackClients } from "../../../utils";
import { conceroNetworks } from "../../../constants";

const usdcAmount = parseUnits("10", 6);
const usdcTokenAddress = process.env.USDC_BASE_SEPOLIA as Address;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE_SEPOLIA as Address;

describe("start deposit usdc to parent pool\n", async () => {
  const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

  const { walletClient, publicClient } = getFallbackClients(conceroNetworks.baseSepolia);

  it("should deposit usdc to pool", async () => {
    const startDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "startDeposit",
      address: poolAddress as Address,
      args: [usdcAmount],
      gas: 3_000_000n,
    });

    const { status, logs } = await publicClient.waitForTransactionReceipt({ hash: startDepositHash, confirmations: 3 });
    const decodedLogs = logs.map(log => {
      try {
        return decodeEventLog({
          abi: ParentPoolAbi,
          data: log.data,
          topics: log.topics,
        });
      } catch (error) {
        return null;
      }
    });

    console.log("transactionHash: ", startDepositHash);

    if (status === "reverted") {
      throw new Error(`Transaction reverted`);
    } else {
      console.log("Transaction successful");
    }

    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

    await sleep(30000);
    await approve(usdcTokenAddress, poolAddress, usdcAmount, walletClient, publicClient);

    const depositRequestId = decodedLogs.find(log => log?.eventName === "DepositInitiated")?.args.requestId;

    console.log("depositRequestId: ", depositRequestId);

    const completeDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "completeDeposit",
      address: poolAddress as Address,
      args: [depositRequestId],
      gas: 3_000_000n,
    });

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
