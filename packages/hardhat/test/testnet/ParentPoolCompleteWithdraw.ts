import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, PrivateKeyAccount } from "viem";
import { PublicClient } from "viem/clients/createPublicClient";
import { abi as ParentPoolAbi } from "../../artifacts/contracts/ConceroParentPool.sol/ConceroParentPool.json";
import { chainsMap } from "../utils/chainsMap";

const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE;
const parentPool = process.env.PARENT_POOL_PROXY_BASE;

describe("complete withdraw from parent pool\n", () => {
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

  it("should retry withdraw from automation", async () => {
    const startDepositHash = await walletClient.writeContract({
      abi: ParentPoolAbi,
      functionName: "completeWithdrawal",
      address: parentPool,
      args: [],
      gas: 3_000_000n,
    });

    const { status, logs } = await srcPublicClient.waitForTransactionReceipt({ hash: startDepositHash });

    console.log("transactionHash: ", startDepositHash);

    if (status === "reverted") {
      throw new Error(`Transaction reverted`);
    } else {
      console.log("Transaction successful");
    }
  }).timeout(0);
});
