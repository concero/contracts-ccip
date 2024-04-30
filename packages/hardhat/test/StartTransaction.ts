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
// import { abi as ConceroAbi } from "../artifacts/contracts/Concero.sol/Concero.json";

describe("startBatchTransactions", () => {
  let Concero: Concero;
  let publicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: baseSepolia,
    transport: http(),
  });
  let viemAccount: PrivateKeyAccount = privateKeyToAccount(("0x" + process.env.TESTS_WALLET_PRIVATE_KEY) as `0x${string}`);
  let nonce;
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
  const transactionsCount = 1;
  const baseContractAddress = process.env.CONCEROCCIP_BASE_SEPOLIA;

  before(async () => {
    nonce = await publicClient.getTransactionCount({
      address: viemAccount.address,
    });
  });

  const approveBnmAndLink = async () => {
    const linkHash = await walletClient.writeContract({
      abi: ERC20ABI,
      functionName: "approve",
      address: linkTokenAddress as `0x${string}`,
      args: [baseContractAddress, 10000000000000000000n],
      nonce,
    });

    nonce++;

    console.log("linkApprovalHash: ", linkHash);

    const bnmHash = await walletClient.writeContract({
      abi: ERC20ABI,
      functionName: "approve",
      address: bnmTokenAddress as `0x${string}`,
      args: [baseContractAddress, BigInt(amount)],
      nonce,
    });

    nonce++;

    console.log("bnmApprovalHash: ", bnmHash);
  };

  it("should start transactions", async () => {
    console.log("should start transactions");
    await approveBnmAndLink();

    const gasPrice = await publicClient.getGasPrice();

    const { request } = await publicClient.simulateContract({
      abi: [
        {
          inputs: [
            {
              internalType: "address",
              name: "_token",
              type: "address",
            },
            {
              internalType: "uint8",
              name: "_tokenType",
              type: "uint8",
            },
            {
              internalType: "uint256",
              name: "_amount",
              type: "uint256",
            },
            {
              internalType: "uint64",
              name: "_destinationChainSelector",
              type: "uint64",
            },
            {
              internalType: "address",
              name: "_receiver",
              type: "address",
            },
          ],
          name: "startTransaction",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        },
      ],
      functionName: "startTransaction",
      address: baseContractAddress as `0x${string}`,
      args: [bnmTokenAddress, 0, BigInt(amount), BigInt(dstChainSelector), senderAddress],
      account: viemAccount as Account,
      value: gasPrice * BigInt(1_500_000),
      nonce: nonce++,
    });
    const hash = await walletClient.writeContract(request);
    console.log("hash: ", hash);
  });
});
