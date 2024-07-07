import "@nomicfoundation/hardhat-chai-matchers";
import { privateKeyToAccount } from "viem/accounts";
import { encodeAbiParameters, formatUnits } from "viem";
import ERC20ABI from "../abi/ERC20.json";
import { abi as ConceroOrchestratorAbi } from "../artifacts/contracts/Orchestrator.sol/Orchestrator.json";
import { getClients } from "../tasks/utils/getViemClients";
import chains from "../constants/CNetworks";
import log from "../utils/log";
import { PublicClient } from "viem/clients/createPublicClient";
import { WalletClient } from "viem/clients/createWalletClient";

const senderAddress = process.env.DEPLOYER_ADDRESS;
const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON;

const srcTokenAddress = process.env.USDC_POLYGON;
const srcTokenAmount = "100000"; // 0.1 USDC

const dstTokenAddress = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063"; // DAI on Polygon
const dstTokenAmount = "999839398359685320";
const dstTokenAmountMin = "994865072994711760";

const srcContractAddress = process.env.CONCERO_PROXY_POLYGON;
const uniswapV3RouterAddress = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";

async function approveToken(
  publicClient: PublicClient,
  walletClient: WalletClient,
  tokenAddress: string,
  amount: string,
) {
  const tokenAlowance = await publicClient.readContract({
    abi: ERC20ABI,
    functionName: "allowance",
    address: tokenAddress as `0x${string}`,
    args: [senderAddress, srcContractAddress],
  });

  log(`tokenAlowance: ${tokenAlowance}`, "swap");

  if (tokenAlowance >= BigInt(amount)) {
    log(`Approval for ${formatUnits(BigInt(amount), 6)} of ${tokenAddress} already exists`, "swap");
    return;
  }

  const senderTokenBalance = await publicClient.readContract({
    abi: ERC20ABI,
    functionName: "balanceOf",
    address: tokenAddress,
    args: [senderAddress],
  });

  log(`senderTokenBalance: ${senderTokenBalance}`, "swap");

  const tokenApprovalTxHash = await walletClient.writeContract({
    abi: ERC20ABI,
    functionName: "approve",
    address: tokenAddress,
    args: [srcContractAddress, BigInt(senderTokenBalance)],
  });

  log(`tokenApprovalTxHash: ${tokenApprovalTxHash}`, "swap");
  await Promise.all([publicClient.waitForTransactionReceipt({ hash: tokenApprovalTxHash })]);
  return tokenApprovalTxHash;
}

describe("swap", () => {
  const { viemChain, url } = chains.polygon;
  const { walletClient, publicClient, account } = getClients(
    viemChain,
    url,
    privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`),
  );

  it("should swap", async () => {
    try {
      await approveToken(publicClient, walletClient, srcTokenAddress, srcTokenAmount);
      const dexData = encodeAbiParameters(
        [{ type: "address" }, { type: "uint24" }, { type: "address" }, { type: "uint160" }],
        [uniswapV3RouterAddress, 100n, senderAddress, 0n],
      );
      const swapData = [
        {
          dexType: 0n,
          fromToken: srcTokenAddress,
          fromAmount: BigInt(srcTokenAmount),
          toToken: dstTokenAddress,
          toAmount: BigInt(dstTokenAmount),
          toAmountMin: BigInt(dstTokenAmountMin),
          dexData,
        },
      ];
      console.log("swapData: ", swapData);

      const swapTxHash = await walletClient.writeContract({
        abi: ConceroOrchestratorAbi,
        functionName: "swap",
        address: srcContractAddress,
        args: [swapData],
        gas: 1_000_000n,
      });

      log(`swapTxHash: ${swapTxHash}`, "swap");
      const { status } = await publicClient.waitForTransactionReceipt({ hash: swapTxHash });
      log(`swap status: ${status}`, "swap");
    } catch (error) {
      log(`Error: ${error}`, "swap");
    }
  }).timeout(0);

  //
  // it("should swapAndBridge", async () => {
  //   try {
  //     await callApprovals();
  //
  //     const dexRouterAddress = "0xF8908a808F1c04396B16A5a5f0A14064324d0EdA";
  //
  //     const dexData = encodeAbiParameters(
  //       [{ type: "address" }, { type: "address[]" }, { type: "address" }, { type: "uint256" }],
  //       [dexRouterAddress, [usdcTokenAddress, bnmTokenAddress], srcContractAddress, 100n],
  //     );
  //
  //     const swapData = [
  //       {
  //         dexType: 0n,
  //         fromToken: usdcTokenAddress,
  //         fromAmount: BigInt(usdcAmount),
  //         toToken: bnmTokenAddress,
  //         toAmount: BigInt(bnmAmount),
  //         toAmountMin: BigInt(bnmAmount),
  //         dexData,
  //       },
  //     ];
  //
  //     const bridgeData = {
  //       tokenType: 0n,
  //       amount: BigInt(bnmAmount),
  //       minAmount: BigInt(bnmAmount),
  //       dstChainSelector: BigInt(dstChainSelector),
  //       receiver: senderAddress,
  //     };
  //
  //     const transactionHash = await walletClient.writeContract({
  //       abi: ConceroOrchestratorAbi,
  //       functionName: "swapAndBridge",
  //       address: srcContractAddress as Address,
  //       args: [bridgeData, swapData, []],
  //       gas: 4_000_000n,
  //     });
  //
  //     console.log("transactionHash: ", transactionHash);
  //
  //     await publicClient.waitForTransactionReceipt({ hash: transactionHash });
  //   } catch (error) {
  //     console.error("Error: ", error);
  //   }
  // }).timeout(0);
});
