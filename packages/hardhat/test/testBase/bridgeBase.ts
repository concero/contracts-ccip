import { approve } from "../utils/approve";

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
    "../../artifacts/contracts/InfraOrchestrator.sol/InfraOrchestrator.json"
  );

  await approve(srcTokenAddress, srcContractAddress, srcTokenAmount, walletClient, publicClient);

  const bridgeData = {
    tokenType: 1n,
    amount: srcTokenAmount,
    dstChainSelector: BigInt(dstChainSelector),
    receiver: senderAddress,
  };

  const bridgeTx = await walletClient.writeContract({
    abi: ConceroOrchestratorAbi,
    functionName: "bridge",
    address: srcContractAddress,
    args: [bridgeData, []],
    gas: 4_000_000n,
  });

  const { status } = await publicClient.waitForTransactionReceipt({ hash: bridgeTx });

  if (status === "success") {
    console.log(`Bridge successful`, "bridge", "hash:", bridgeTx);
  } else {
    throw new Error(`Bridge failed. Hash: ${bridgeTx}`);
  }
}
