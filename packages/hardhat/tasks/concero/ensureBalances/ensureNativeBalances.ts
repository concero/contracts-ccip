import { mainnetChains, messengerTargetBalances, testnetChains, viemReceiptConfig } from "../../../constants";
import { getEnvAddress, getEnvVar, getFallbackClients } from "../../../utils";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { formatEther, parseEther } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import log, { err } from "../../../utils/log";
import { type BalanceInfo } from "./types";
import readline from "readline";

const donorAccount = privateKeyToAccount(`0x${getEnvVar("DEPLOYER_PRIVATE_KEY")}`);
const wallets = [
  getEnvAddress("poolMessenger0"),
  getEnvAddress("infraMessenger0"),
  // getEnvAddress("infraMessenger1"),
  // getEnvAddress("infraMessenger2"),
];

const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

// export async function ensureWalletBalance(wallet: string, targetBalances: Record<string, bigint>, chain: CNetwork) {
//   const balance = await checkNativeBalance(wallet, targetBalances, chain);
//   const displayedWalletBalances = {
//     chain: balance.chain.name,
//     address: balance.address,
//     balance: balance.balance,
//     targetBalance: balance.targetBalance,
//     deficit: balance.deficit,
//   };
//
//   if (parseFloat(balance.deficit) > 0) {
//     err(
//       `Insufficient balance for ${wallet}. Balance: ${balance.balance}. Deficit: ${balance.deficit}`,
//       "ensureWalletBalance",
//       chain.name,
//     );
//     throw new Error();
//   }
//   console.table([displayedWalletBalances]);
//   return balance;
// }

async function checkNativeBalance(
  address: string,
  alias: string,
  targetBalances: Record<string, bigint>,
  chain: CNetwork,
): Promise<BalanceInfo> {
  const { publicClient } = getFallbackClients(chain);
  const balance = await publicClient.getBalance({ address });
  const targetBalance = targetBalances[chain.name] || BigInt(0);
  const deficit = balance < targetBalance ? targetBalance - balance : BigInt(0);

  return {
    chain,
    address,
    alias,
    balance,
    donorBalance: BigInt(0),
    targetBalance,
    deficit,
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
      `Topped up ${wallet} with ${formatEther(amount)} ETH. Tx: ${hash} Gas used: ${setDexRouterGasUsed}`,
      "topUpWallet",
      publicClient.chain.name,
    );
  } catch (error) {
    err(`Error topping up ${wallet} on ${publicClient.chain.name}: ${error} `, "topUpWallet");
  }
}

async function getBalanceInfo(addresses: [string, string][], chain: CNetwork): Promise<BalanceInfo[]> {
  const balancePromises = addresses.map(([address, alias]) =>
    checkNativeBalance(address, alias, messengerTargetBalances, chain),
  );
  return await Promise.all(balancePromises);
}

async function performTopUps(walletBalances: BalanceInfo[], donorAccount: any): Promise<void> {
  const topUpPromises = walletBalances.map(async walletInfo => {
    const deficit = parseEther(walletInfo.deficit);
    if (deficit > BigInt(0)) {
      const { publicClient, walletClient } = getFallbackClients(walletInfo.chain, donorAccount);
      await topUpWallet(walletInfo.address, publicClient, walletClient, deficit);
    }
  });
  await Promise.all(topUpPromises);
}

async function ensureNativeBalances(isTestnet: boolean) {
  const chains = isTestnet ? testnetChains : mainnetChains;
  const allBalances: Record<string, BalanceInfo[]> = {};

  try {
    const balancePromises = chains.map(async chain => {
      const walletInfos = await getBalanceInfo(wallets, chain);
      const donorInfo = await getBalanceInfo([[donorAccount.address, "Donor"]], chain);
      allBalances[chain.name] = [...walletInfos, ...donorInfo];
    });

    await Promise.all(balancePromises);

    const displayedBalances = Object.entries(allBalances).flatMap(([chainName, balances]) => {
      const donorBalance = balances.find(b => b.alias === "Donor");
      return balances
        .filter(b => b.alias !== "Donor")
        .map(info => ({
          chain: chainName,
          address: info.alias,
          balance: formatEther(info.balance),
          target: formatEther(info.targetBalance),
          deficit: formatEther(info.deficit),
          donorBalance: formatEther(donorBalance?.balance || BigInt(0)),
        }));
    });

    console.log("\nWallet and Donor Balances:");
    console.table(displayedBalances);

    const totalDeficit = displayedBalances.reduce((sum, info) => sum + parseFloat(info.deficit), 0);
    if (totalDeficit > 0) {
      const answer = await prompt(
        `Do you want to perform top-ups for a total of ${formatEther(totalDeficit)} ETH? (y/n): `,
      );
      if (answer.toLowerCase() === "y") {
        const walletBalances = Object.values(allBalances)
          .flat()
          .filter(b => b.alias !== "Donor");
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

task("ensure-native-balances", "Ensure balances of wallets")
  .addFlag("testnet")
  .setAction(async taskArgs => {
    await ensureNativeBalances(taskArgs.testnet);
  });

export default ensureNativeBalances;
