import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { Address, createPublicClient, createWalletClient, PrivateKeyAccount } from "viem";
import { PublicClient } from "viem/clients/createPublicClient";
import { abi as ParentPoolAbi } from "../../artifacts/contracts/ConceroParentPool.sol/ConceroParentPool.json";
import { chainsMap } from "../utils/chainsMap";
import { approve } from "../utils/approve";

const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE;
const usdcAmount = "100000000";
const usdcTokenAddress = process.env.USDC_BASE as Address;
const poolAddress = process.env.PARENT_POOL_PROXY_BASE as Address;
//todo refactor
describe("start deposit usdc to parent pool\n", () => {
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

  it("should deposit usdc to pool", async () => {
    const startDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "startDeposit",
      address: poolAddress as Address,
      args: [BigInt(usdcAmount)],
      gas: 3_000_000n,
    });

    const { status, logs } = await srcPublicClient.waitForTransactionReceipt({ hash: startDepositHash });

    console.log("transactionHash: ", startDepositHash);

    if (status === "reverted") {
      throw new Error(`Transaction reverted`);
    } else {
      console.log("Transaction successful");
    }

    const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

    await sleep(40000);

    await approve(usdcTokenAddress, poolAddress, BigInt(usdcAmount), walletClient, srcPublicClient);

    const completeDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "completeDeposit",
      address: poolAddress as Address,
      args: [logs[0].topics[1]],
      gas: 3_000_000n,
    });

    console.log("completeDepositHash: ", completeDepositHash);

    const { status: completeDepositStatus } = await srcPublicClient.waitForTransactionReceipt({
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
