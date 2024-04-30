import { Concero } from "../typechain-types";
import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, http, PrivateKeyAccount } from "viem";
import { baseSepolia } from "viem/chains";
import ERC20ABI from "../abi/ERC20.json";
import { PublicClient } from "viem/clients/createPublicClient";
import { abi as ConceroAbi } from "../artifacts/contracts/Concero.sol/Concero.json";

describe("startBatchTransactions", () => {
  let Concero: Concero;
  let publicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: baseSepolia,
    transport: http(),
  });
  let viemAccount: PrivateKeyAccount = privateKeyToAccount(("0x" + process.env.TESTS_WALLET_PRIVATE_KEY) as `0x${string}`);
  let nonce: BigInt;
  let walletClient: WalletClient<HttpTransport, Chain, Account, RpcSchema> = createWalletClient({
    chain: baseSepolia,
    transport: http(),
    account: viemAccount,
  });

  const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA;
  const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA;
  const senderAddress = process.env.TESTS_WALLET_ADDRESS;
  const amount = "100000000000000";
  const bnmTokenAddress = process.env.CCIPBNM_BASE_SEPOLIA;
  const linkTokenAddress = process.env.LINK_BASE_SEPOLIA;
  const transactionsCount = 30;
  const baseContractAddress = process.env.CONCEROCCIP_BASE_SEPOLIA;

  before(async () => {
    nonce = await publicClient.getTransactionCount({
      address: viemAccount.address,
    });
  });

  const approveBnmAndLink = async () => {
    const approveToken = async (tokenAddress: string) => {
      const tokenAmount = await publicClient.readContract({
        abi: ERC20ABI,
        functionName: "balanceOf",
        address: tokenAddress as `0x${string}`,
        args: [senderAddress],
      });

      const tokenHash = await walletClient.writeContract({
        abi: ERC20ABI,
        functionName: "approve",
        address: tokenAddress as `0x${string}`,
        args: [baseContractAddress, BigInt(tokenAmount)],
        nonce: nonce++,
      });

      console.log("tokenApprovalHash: ", tokenHash);

      return tokenHash;
    };

    const bnmHash = await approveToken(bnmTokenAddress);
    const linkHash = await approveToken(linkTokenAddress);

    await Promise.all([publicClient.waitForTransactionReceipt({ hash: bnmHash }), publicClient.waitForTransactionReceipt({ hash: linkHash })]);
  };

  it("should start transactions", async () => {
    await approveBnmAndLink();

    let transactionPromises = [];

    for (let i = 0; i < transactionsCount; i++) {
      const gasPrice = await publicClient.getGasPrice();
      const { request } = await publicClient.simulateContract({
        abi: ConceroAbi,
        functionName: "startTransaction",
        address: baseContractAddress as `0x${string}`,
        args: [bnmTokenAddress, 0, BigInt(amount), BigInt(dstChainSelector), senderAddress],
        account: viemAccount as Account,
        value: gasPrice * BigInt(1_600_000),
        nonce: nonce++,
      });

      transactionPromises.push(walletClient.writeContract(request));
    }

    const transactionHashes = await Promise.all(transactionPromises);
    console.log("transactionHashes: ", transactionHashes);
  });
});
