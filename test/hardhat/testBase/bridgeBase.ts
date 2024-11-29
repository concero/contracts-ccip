import { approve } from "../utils/approve";
import { encodeAbiParameters, zeroAddress } from "viem";
import * as solady from "solady";

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

  const dstSwapData = [
    {
      dexType: 3,
      fromToken: "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359",
      fromAmount: 9555601n,
      toToken: "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",
      toAmount: 17218152113414787280n,
      toAmountMin: 17132489665089340577n,
      dexData:
        "0x000000000000000000000000e592427a0aece92de3edee1f18e0157c0586156400000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000067489f29",
    },
  ];

  const encodedDstSwapData = encodeAbiParameters(
    [
      {
        components: [
          {
            internalType: "enum IDexSwap.DexType",
            name: "dexType",
            type: "uint8",
          },
          {
            internalType: "address",
            name: "fromToken",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "fromAmount",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "toToken",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "toAmount",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "toAmountMin",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "dexData",
            type: "bytes",
          },
        ],
        internalType: "struct IDexSwap.SwapData[]",
        name: "_swapData",
        type: "tuple[]",
      },
    ],
    [dstSwapData],
  );

  const compressedDstSwapData = solady.LibZip.cdCompress(encodedDstSwapData);

  const bridgeTx = await walletClient.writeContract({
    abi: ConceroOrchestratorAbi,
    functionName: "bridge",
    address: srcContractAddress,
    args: [bridgeData, compressedDstSwapData, integration],
    gas: 4_000_000n,
  });

  const { status } = await publicClient.waitForTransactionReceipt({ hash: bridgeTx });

  if (status === "success") {
    console.log(`Bridge successful`, "bridge", "hash:", bridgeTx);
  } else {
    throw new Error(`Bridge failed. Hash: ${bridgeTx}`);
  }
}
