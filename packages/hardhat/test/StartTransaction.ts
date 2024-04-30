import { Concero } from "../typechain-types";
import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, decodeEventLog, http, PrivateKeyAccount } from "viem";
import { baseSepolia, optimismSepolia } from "viem/chains";
import ERC20ABI from "../abi/ERC20.json";
import { PublicClient } from "viem/clients/createPublicClient";
import { abi as ConceroAbi } from "../artifacts/contracts/Concero.sol/Concero.json";

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

describe("startBatchTransactions", () => {
  let Concero: Concero;
  let srcPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: baseSepolia,
    transport: http(`https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`),
  });
  let dstPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: optimismSepolia,
    transport: http(`https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
  });
  let viemAccount: PrivateKeyAccount = privateKeyToAccount(
    ("0x" + process.env.TESTS_WALLET_PRIVATE_KEY) as `0x${string}`,
  );
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
  const transactionsCount = 1;
  const srcContractAddress = process.env.CONCEROCCIP_BASE_SEPOLIA;
  const dstContractAddress = process.env.CONCEROCCIP_OPTIMISM_SEPOLIA;

  before(async () => {
    nonce = await srcPublicClient.getTransactionCount({
      address: viemAccount.address,
    });
  });

  const approveBnmAndLink = async () => {
    const approveToken = async (tokenAddress: string) => {
      const tokenAmount = await srcPublicClient.readContract({
        abi: ERC20ABI,
        functionName: "balanceOf",
        address: tokenAddress as `0x${string}`,
        args: [senderAddress],
      });

      const tokenHash = await walletClient.writeContract({
        abi: ERC20ABI,
        functionName: "approve",
        address: tokenAddress as `0x${string}`,
        args: [srcContractAddress, BigInt(tokenAmount)],
        nonce: nonce++,
      });

      console.log("tokenApprovalHash: ", tokenHash);

      return tokenHash;
    };

    const bnmHash = await approveToken(bnmTokenAddress);
    const linkHash = await approveToken(linkTokenAddress);

    await Promise.all([
      srcPublicClient.waitForTransactionReceipt({ hash: bnmHash }),
      srcPublicClient.waitForTransactionReceipt({ hash: linkHash }),
    ]);
  };

  const checkTransactionStatus = async (transactionHash: string, fromSrcBlockNumber: string, fromDstBlock: string) => {
    await srcPublicClient.waitForTransactionReceipt({ hash: transactionHash });

    const getLog = async (
      id: string,
      eventName: string,
      contractAddress: string,
      viemPublicClient: any,
      fromBlock: string,
    ): Promise<any | null> => {
      console.log(id, eventName, contractAddress, viemPublicClient.chain.id, fromBlock);
      const logs = await viemPublicClient.getLogs({
        address: contractAddress,
        abi: ConceroAbi,
        fromBlock: fromBlock,
        toBlock: "latest",
      });

      const filteredLog = logs.find((log: any) => {
        const decodedLog: any = decodeEventLog({
          abi: ConceroAbi,
          data: log.data,
          topics: log.topics,
        });

        const logId = eventName === "CCIPSent" ? log.transactionHash : decodedLog.args.ccipMessageId;
        return logId?.toLowerCase() === id.toLowerCase() && decodedLog.eventName === eventName;
      });

      if (!filteredLog) {
        return null;
      }

      return decodeEventLog({
        abi: ConceroAbi,
        data: filteredLog.data,
        topics: filteredLog.topics,
      });
    };

    const ccipMessageId = (
      await getLog(transactionHash, "CCIPSent", srcContractAddress, srcPublicClient, fromSrcBlockNumber)
    ).args.ccipMessageId;

    console.log("ccipMessageId: ", ccipMessageId);

    let dstLog = null;
    while (dstLog === null) {
      dstLog = await getLog(ccipMessageId, "TXReleased", dstContractAddress, dstPublicClient, fromDstBlock);
      console.log("dstLogs: ", dstLog);
      await sleep(2000);
    }

    return dstLog;
  };

  it("should start transactions", async () => {
    const fromSrcBlockNumber = await srcPublicClient.getBlockNumber();
    const fromDstBlockNumber = await dstPublicClient.getBlockNumber();

    await approveBnmAndLink();

    let transactionPromises = [];

    for (let i = 0; i < transactionsCount; i++) {
      const gasPrice = await srcPublicClient.getGasPrice();
      const { request } = await srcPublicClient.simulateContract({
        abi: ConceroAbi,
        functionName: "startTransaction",
        address: srcContractAddress as `0x${string}`,
        args: [bnmTokenAddress, 0, BigInt(amount), BigInt(dstChainSelector), senderAddress],
        account: viemAccount as Account,
        value: gasPrice * BigInt(1_600_000),
        nonce: nonce++,
      });

      transactionPromises.push(walletClient.writeContract(request));
    }

    const transactionHashes = await Promise.all(transactionPromises);
    console.log("transactionHashes: ", transactionHashes);

    const status = await checkTransactionStatus(
      transactionHashes[0],
      "0x" + fromSrcBlockNumber.toString(16),
      "0x" + fromDstBlockNumber.toString(16),
    );

    console.log("status: ", status);
  }).timeout(0);
});
