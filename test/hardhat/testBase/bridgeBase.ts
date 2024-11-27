import { approve } from "../utils/approve";
import { zeroAddress } from "viem";

export interface IBridgeBase {
  srcTokenAddress: string;
  srcTokenAmount: bigint;
  srcContractAddress: string;
  dstChainSelector: number;
  senderAddress: string;
  walletClient: any;
  publicClient: any;
}

export async function bridgeBase({
  srcTokenAddress,
  srcTokenAmount,
  srcContractAddress,
  dstChainSelector,
  senderAddress,
  walletClient,
  publicClient,
}: IBridgeBase) {
  const { abi: ConceroOrchestratorAbi } = await import(
    "../../../artifacts/contracts/InfraOrchestrator.sol/InfraOrchestrator.json"
  );

  await approve(srcTokenAddress, srcContractAddress, srcTokenAmount, walletClient, publicClient);

  const bridgeData = {
    dstChainSelector: BigInt(dstChainSelector),
    receiver: senderAddress,
    amount: srcTokenAmount,
  };

  const integration = {
    integrator: zeroAddress,
    feeBps: 0n,
  };

  const bridgeTx = await walletClient.writeContract({
    abi: ConceroOrchestratorAbi,
    functionName: "bridge",
    address: srcContractAddress,
    args: [bridgeData, "", integration],
    gas: 4_000_000n,
  });

  const { status } = await publicClient.waitForTransactionReceipt({ hash: bridgeTx });

  if (status === "success") {
    console.log(`Bridge successful`, "bridge", "hash:", bridgeTx);
  } else {
    throw new Error(`Bridge failed. Hash: ${bridgeTx}`);
  }
}
