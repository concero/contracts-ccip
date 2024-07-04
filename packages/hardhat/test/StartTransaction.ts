import { Concero } from "../typechain-types";
import "@nomicfoundation/hardhat-chai-matchers";
import { WalletClient } from "viem/clients/createWalletClient";
import { HttpTransport } from "viem/clients/transports/http";
import { Chain } from "viem/types/chain";
import type { Account } from "viem/accounts/types";
import { RpcSchema } from "viem/types/eip1193";
import { privateKeyToAccount } from "viem/accounts";
import { Address, createPublicClient, createWalletClient, decodeEventLog, http, PrivateKeyAccount } from "viem";
import { arbitrumSepolia, base, baseSepolia, optimismSepolia, polygon, polygonAmoy } from "viem/chains";
import ERC20ABI from "../abi/ERC20.json";
import { PublicClient } from "viem/clients/createPublicClient";
import { abi as ConceroAbi } from "../artifacts/contracts/Concero.sol/Concero.json";
import { abi as ConceroOrchestratorAbi } from "../artifacts/contracts/Orchestrator.sol/Orchestrator.json";

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

const chainsMap = {
  [process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA]: {
    viemChain: optimismSepolia,
    viemTransport: http(`https://optimism-sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA]: {
    viemChain: baseSepolia,
    viemTransport: http(`https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA]: {
    viemChain: arbitrumSepolia,
    viemTransport: http(),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY]: {
    viemChain: polygonAmoy,
    viemTransport: http(`https://polygon-amoy.infura.io/v3/${process.env.INFURA_API_KEY}`),
  },

  // mainnets
  [process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON]: {
    viemChain: polygon,
    viemTransport: http(`https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`),
  },
  [process.env.CL_CCIP_CHAIN_SELECTOR_BASE]: {
    viemChain: base,
    viemTransport: http(),
  },
};

const srcChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON;
const dstChainSelector = process.env.CL_CCIP_CHAIN_SELECTOR_BASE;
const senderAddress = process.env.DEPLOYER_ADDRESS;
const amount = "1000000";
// const bnmTokenAddress = process.env.CCIPBNM_OPTIMISM_SEPOLIA;
const usdcTokenAddress = process.env.USDC_POLYGON;
const transactionsCount = 1;
const srcContractAddress = process.env.CONCERO_PROXY_POLYGON;
const dstContractAddress = process.env.CONCERO_PROXY_BASE;

describe("startBatchTransactions\n", () => {
  let Concero: Concero;
  let srcPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
  });
  let dstPublicClient: PublicClient<HttpTransport, Chain, Account, RpcSchema> = createPublicClient({
    chain: chainsMap[dstChainSelector].viemChain,
    transport: chainsMap[dstChainSelector].viemTransport,
  });

  let viemAccount: PrivateKeyAccount = privateKeyToAccount(("0x" + process.env.DEPLOYER_PRIVATE_KEY) as `0x${string}`);
  let nonce: BigInt;
  let walletClient: WalletClient<HttpTransport, Chain, Account, RpcSchema> = createWalletClient({
    chain: chainsMap[srcChainSelector].viemChain,
    transport: chainsMap[srcChainSelector].viemTransport,
    account: viemAccount,
  });

  before(async () => {
    nonce = BigInt(
      await srcPublicClient.getTransactionCount({
        address: viemAccount.address,
      }),
    );
  });

  const approveBnmAndLink = async () => {
    const approveToken = async (tokenAddress: string) => {
      const tokenAllowance = await srcPublicClient.readContract({
        abi: ERC20ABI,
        functionName: "allowance",
        address: tokenAddress as `0x${string}`,
        args: [senderAddress, srcContractAddress],
      });

      if (tokenAllowance >= BigInt(amount)) {
        return null;
      }

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

    const bnmHash = await approveToken(usdcTokenAddress);
    // const linkHash = await approveToken(linkTokenAddress);

    if (!bnmHash) return;

    await Promise.all([srcPublicClient.waitForTransactionReceipt({ hash: bnmHash })]);
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
      if (dstLog) {
        console.log("dstLogs: ", dstLog);
      }
      await sleep(5000);
    }

    return dstLog;
  };

  it("should start transactions", async () => {
    await approveBnmAndLink();

    const gasPrice = await srcPublicClient.getGasPrice();

    const fromSrcBlockNumber = await srcPublicClient.getBlockNumber();
    const fromDstBlockNumber = await dstPublicClient.getBlockNumber();
    let transactionPromises = [];
    const bridgeData = {
      tokenType: 1n,
      amount: BigInt(amount),
      minAmount: BigInt(amount),
      dstChainSelector: BigInt(dstChainSelector),
      receiver: senderAddress,
    };

    for (let i = 0; i < transactionsCount; i++) {
      // const { request } = await srcPublicClient.simulateContract({
      //   abi: ConceroOrchestratorAbi,
      //   functionName: "bridge",
      //   address: srcContractAddress as Address,
      //   args: [bridgeData, []],
      //   account: viemAccount as Account,
      //   // nonce: nonce++,
      // });
      // transactionPromises.push(walletClient.writeContract(request));

      const transactionHash = walletClient.writeContract({
        abi: ConceroOrchestratorAbi,
        functionName: "bridge",
        address: srcContractAddress as Address,
        args: [bridgeData, []],
        // nonce: nonce++,
        gas: 3_000_000n,
        // gasPrice: gasPrice,
      });
      transactionPromises.push(transactionHash);
    }

    const transactionHashes = await Promise.all(transactionPromises);
    console.log("transactionHashes: ", transactionHashes);

    const txStatusPromises = transactionHashes.map(txHash => {
      return checkTransactionStatus(
        txHash,
        "0x" + fromSrcBlockNumber.toString(16),
        "0x" + fromDstBlockNumber.toString(16),
      );
    });

    const txStatuses = await Promise.all(txStatusPromises);
    console.log("txStatuses: ", txStatuses);
  }).timeout(0);
});
