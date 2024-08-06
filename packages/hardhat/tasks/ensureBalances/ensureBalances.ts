import { liveChains } from "../concero/liveChains";
import { getFallbackClients } from "../utils/getViemClients";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { formatEther, parseEther } from "viem";
import { type CNetwork } from "../../types/CNetwork";
import log from "../../utils/log";
import { type BalanceInfo } from "./types";
import { getEnvVar } from "../../utils/getEnvVar";
import readline from "readline";
import { viemReceiptConfig } from "../../constants/deploymentVariables";

const targetBalances: Record<string, bigint> = {
  mainnet: parseEther("0.01"),
  arbitrum: parseEther("0.01"),
  polygon: parseEther("12.5"),
  avalanche: parseEther("0.01"),
  base: parseEther("0.01"),
};

const wallets = [getEnvVar("MESSENGER_0_ADDRESS"), getEnvVar("POOL_MESSENGER_0_ADDRESS")];
const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

async function checkWalletBalance(wallet: string, publicClient: any, chain: CNetwork): Promise<BalanceInfo> {
  const balance = await publicClient.getBalance({ address: wallet });
  const targetBalance = targetBalances[chain.name] || BigInt(0);
  const deficit = balance < targetBalance ? targetBalance - balance : BigInt(0);

  return {
    chain,
    address: wallet,
    balance: formatEther(balance),
    target: formatEther(targetBalance),
    deficit: formatEther(deficit),
  };
}

async function topUpWallet(wallet: string, publicClient: any, walletClient: any, amount: bigint): Promise<void> {
  try {
    const hash = await walletClient.sendTransaction({ to: wallet, value: amount });
    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });
    log(
      `Topped up ${wallet} on ${publicClient.chain.name} with ${formatEther(amount)} ETH. Tx: ${hash}. Gas used: ${setDexRouterGasUsed}`,
      "topUpWallet",
    );
  } catch (error) {
    console.error(`Error topping up ${wallet} on ${publicClient.chain.name}:`, error);
  }
}

async function collectChainInfo(chain: CNetwork, donorAccount: any): Promise<[BalanceInfo, BalanceInfo[]]> {
  const { publicClient } = getFallbackClients(chain, donorAccount);

  const donorBalance = await publicClient.getBalance({ address: donorAccount.address });

  const donorInfo: BalanceInfo = {
    chain,
    address: donorAccount.address,
    balance: formatEther(donorBalance),
    target: "N/A",
    deficit: "N/A",
  };

  const walletInfos: BalanceInfo[] = [];
  for (const wallet of wallets) {
    const walletInfo = await checkWalletBalance(wallet, publicClient, chain);
    walletInfos.push(walletInfo);
  }

  return [donorInfo, walletInfos];
}

async function performTopUps(walletBalances: BalanceInfo[], donorAccount: any): Promise<void> {
  for (const walletInfo of walletBalances) {
    const deficit = parseEther(walletInfo.deficit);

    if (deficit > BigInt(0)) {
      const { publicClient, walletClient } = getFallbackClients(walletInfo.chain, donorAccount);
      await topUpWallet(walletInfo.address, publicClient, walletClient, deficit);
    }
  }
}

async function ensureBalances() {
  const donorAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
  const donorBalances: BalanceInfo[] = [];
  const walletBalances: BalanceInfo[] = [];

  try {
    for (const chain of liveChains) {
      const [donorInfo, walletInfos] = await collectChainInfo(chain, donorAccount);
      donorBalances.push(donorInfo);
      walletBalances.push(...walletInfos);
    }

    const displayedDonorBalances = donorBalances.map(info => ({
      chain: info.chain.name,
      address: info.address,
      balance: info.balance,
    }));

    const displayedWalletBalances = walletBalances.map(info => ({
      chain: info.chain.name,
      address: info.address,
      balance: info.balance,
      target: info.target,
      deficit: info.deficit,
    }));

    console.log("\nDonor Balances:");
    console.table(displayedDonorBalances);

    console.log("\nWallet Balances:");
    console.table(displayedWalletBalances);

    const totalDeficit = walletBalances.reduce((sum, info) => sum + parseFloat(info.deficit), 0);
    if (totalDeficit > 0) {
      const answer = await prompt(
        `Do you want to perform top-ups for a total of ${totalDeficit.toFixed(6)} ETH? (y/n): `,
      );
      if (answer.toLowerCase() === "y") {
        await performTopUps(walletBalances, donorAccount);
      } else {
        console.log("Top-ups cancelled.");
      }
    } else {
      console.log("No top-ups needed.");
    }
  } finally {
    rl.close();
  }
}

task("ensure-balances", "Ensure balances of wallets").setAction(async () => {
  await ensureBalances();
});

export default ensureBalances;
