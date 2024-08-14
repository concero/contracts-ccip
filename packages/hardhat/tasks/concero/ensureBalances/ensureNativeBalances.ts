import { mainnetChains, testnetChains } from "../liveChains";
import { getFallbackClients } from "../../../utils/getViemClients";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { formatEther, parseEther } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import log, { err } from "../../../utils/log";
import { type BalanceInfo } from "./types";
import { getEnvVar } from "../../../utils/getEnvVar";
import readline from "readline";
import { viemReceiptConfig } from "../../../constants/deploymentVariables";
import { messengerTargetBalances } from "../../../constants/targetBalances";

const donorAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
const wallets = [getEnvVar("MESSENGER_0_ADDRESS"), getEnvVar("POOL_MESSENGER_0_ADDRESS")];
const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

export async function ensureWalletBalance(wallet: string, targetBalances: Record<string, bigint>, chain: CNetwork) {
  const balance = await checkWalletBalance(wallet, targetBalances, chain);
  const displayedWalletBalances = {
    chain: balance.chain.name,
    address: balance.address,
    balance: balance.balance,
    target: balance.target,
    deficit: balance.deficit,
  };

  if (parseFloat(balance.deficit) > 0) {
    err(
      `Insufficient balance for ${wallet}. Balance: ${balance.balance}. Deficit: ${balance.deficit}`,
      "ensureWalletBalance",
      chain.name,
    );
    throw new Error();
  }
  console.table([displayedWalletBalances]);
  return balance;
}

export async function checkWalletBalance(
  wallet: string,
  targetBalances: Record<string, bigint>,
  chain: CNetwork,
): Promise<BalanceInfo> {
  const { publicClient } = getFallbackClients(chain);

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
      `Topped up ${wallet} with ${formatEther(amount)} ETH. Tx: ${hash}. Gas used: ${setDexRouterGasUsed}`,
      "topUpWallet",
      publicClient.chain.name,
    );
  } catch (error) {
    err(`Error topping up ${wallet} on ${publicClient.chain.name}: ${error} `, "topUpWallet");
  }
}

async function getBalanceInfo(targetAddresses: [], chain: CNetwork): Promise<BalanceInfo[]> {
  const walletInfos: BalanceInfo[] = [];
  for (const wallet of targetAddresses) {
    const walletInfo = await checkWalletBalance(wallet, messengerTargetBalances, chain);
    walletInfos.push(walletInfo);
  }

  return walletInfos;
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

async function ensureNativeBalances(isTestnet: boolean) {
  const donorBalances: BalanceInfo[] = [];
  const walletBalances: BalanceInfo[] = [];
  const chains = isTestnet ? testnetChains : mainnetChains;

  try {
    for (const chain of chains) {
      const walletInfos = await getBalanceInfo(wallets, chain);
      const donorInfo = await getBalanceInfo([donorAccount.address], chain);

      donorBalances.push(...donorInfo);
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

task("ensure-balances", "Ensure balances of wallets")
  .addFlag("testnet")
  .setAction(async taskArgs => {
    await ensureNativeBalances(taskArgs.testnet);
  });

export default ensureNativeBalances;
