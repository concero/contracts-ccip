import "@nomicfoundation/hardhat-chai-matchers";
import { formatUnits } from "viem";
import ERC20ABI from "../abi/ERC20.json";
import { abi as ConceroOrchestratorAbi } from "../artifacts/contracts/Orchestrator.sol/Orchestrator.json";
import { getFallbackClients } from "../utils/getViemClients";
import chains from "../constants/cNetworks";
import log from "../utils/log";
import { PublicClient } from "viem/clients/createPublicClient";
import { WalletClient } from "viem/clients/createWalletClient";

const senderAddress = process.env.DEPLOYER_ADDRESS;
const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_AVALANCHE;
const srcTokenAddress = process.env.USDC_ARBITRUM;
const srcTokenAmount = "1000000";
const srcContractAddress = process.env.CONCERO_PROXY_ARBITRUM;
const { viemChain, url } = chains.arbitrum;

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

describe("bridge", () => {
  const { walletClient, publicClient, account } = getFallbackClients(chains.arbitrum);

  it("should bridge", async () => {
    try {
      await approveToken(publicClient, walletClient, srcTokenAddress, srcTokenAmount);

      const bridgeData = {
        tokenType: 1n,
        amount: BigInt(srcTokenAmount),
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

      log(`bridgeTxHash: ${bridgeTx}`, "bridge");
      const { status } = await publicClient.waitForTransactionReceipt({ hash: bridgeTx });
      log(`bridge status: ${status}`, "bridge");
    } catch (error) {
      log(`Error: ${error}`, "bridge");
    }
  }).timeout(0);
});
