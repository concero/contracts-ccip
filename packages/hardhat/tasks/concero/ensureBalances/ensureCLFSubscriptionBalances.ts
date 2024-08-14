import { mainnetChains, testnetChains } from "../liveChains";
import { getFallbackClients } from "../../../utils/getViemClients";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { formatEther, parseEther } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import log, { err } from "../../../utils/log";
import readline from "readline";
import { viemReceiptConfig } from "../../../constants/deploymentVariables";
import functionsRouterAbi from "@chainlink/contracts/abi/v0.8/FunctionsRouter.json";

const donorAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
const minBalance = parseEther("1");

const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

interface SubscriptionInfo {
  chain: CNetwork;
  balance: bigint;
  deficit: bigint;
}

async function checkSubscriptionBalance(chain: CNetwork): Promise<SubscriptionInfo> {
  const { publicClient } = getFallbackClients(chain);
  const { functionsRouter, name, functionsSubIds } = chain;
  const subId = functionsSubIds[0];
  const subscriptionData = await publicClient.readContract({
    address: functionsRouter,
    abi: functionsRouterAbi,
    functionName: "getSubscription",
    args: [BigInt(subId)]
  });
  
  // Extract the balance from the subscription data
  const balance = subscriptionData.balance;
  const deficit = balance < minBalance ? minBalance - balance : BigInt(0);

  return { chain, balance, deficit };
}

async function topUpSubscription(chain: CNetwork, amount: bigint): Promise<void> {
  const { publicClient, walletClient } = getFallbackClients(chain, donorAccount);
  const { functionsRouter, name, functionsSubIds } = chain;
  const subId = functionsSubIds[0];
  try {
    const hash = await walletClient.writeContract({
      address: functionsRouter,
      abi: functionsRouterAbi,
      functionName: "addFunds",
      args: [BigInt(subId), amount]
    });

    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });

    log(
      `Topped up subscription ${subId} with ${formatEther(amount)} LINK on ${chain.name}. Tx: ${hash}. Gas used: ${cumulativeGasUsed}`,
      "topUpSubscription",
      chain.name
    );
  } catch (error) {
    err(`Error topping up subscription ${subId} on ${chain.name}: ${error}`, "topUpSubscription");
  }
}

async function ensureCLFSubscriptionBalances(isTestnet: boolean) {
  const chains = isTestnet ? testnetChains : mainnetChains;
  const subscriptionInfos: SubscriptionInfo[] = [];

  try {
    const subscriptionPromises = chains.map(chain => checkSubscriptionBalance(chain));

    // Wait for all promises to resolve simultaneously
    const subscriptionInfos = await Promise.all(subscriptionPromises);

    const displayedBalances = subscriptionInfos.map(info => ({
      chain: info.chain.name,
      balance: formatEther(info.balance),
      deficit: formatEther(info.deficit),
    }));

    console.log("\nCLF Subscription Balances:");
    console.table(displayedBalances);

    const totalDeficit = subscriptionInfos.reduce((sum, info) => sum + info.deficit, BigInt(0));

    if (totalDeficit > BigInt(0)) {
      const answer = await prompt(
        `Do you want to perform top-ups for a total of ${formatEther(totalDeficit)} LINK? (y/n): `
      );

      if (answer.toLowerCase() === "y") {
        for (const info of subscriptionInfos) {
          if (info.deficit > BigInt(0)) {
            await topUpSubscription(info.chain, info.deficit);
          }
        }
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

task("ensure-clf-subscription-balances", "Ensure CLF subscription balances")
  .addFlag("testnet")
  .setAction(async taskArgs => {
    await ensureCLFSubscriptionBalances(taskArgs.testnet);
  });

export default ensureCLFSubscriptionBalances;
