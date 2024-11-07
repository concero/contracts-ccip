import { mainnetChains, testnetChains, viemReceiptConfig } from "../../../constants";
import { err, getFallbackClients, log } from "../../../utils";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { formatEther, parseEther } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import readline from "readline";
import functionsRouterAbi from "@chainlink/contracts/abi/v0.8/FunctionsRouter.json";
import checkERC20Balance from "./checkERC20Balance";
import linkTokenAbi from "@chainlink/contracts/abi/v0.8/LinkToken.json";
import { BalanceInfo } from "./types";

const donorAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
const minBalance = parseEther("20");

const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

async function checkSubscriptionBalance(chain: CNetwork): Promise<BalanceInfo> {
  const { publicClient } = getFallbackClients(chain);
  const { functionsRouter, name, functionsSubIds, linkToken } = chain;
  const subId = functionsSubIds[0];
  const subscriptionData = await publicClient.readContract({
    address: functionsRouter,
    abi: functionsRouterAbi,
    functionName: "getSubscription",
    args: [BigInt(subId)],
  });

  const balance = subscriptionData.balance;
  const deficit = balance < minBalance ? minBalance - balance : BigInt(0);
  const { balance: donorBalance } = await checkERC20Balance(chain, linkToken, donorAccount.address);
  return { chain, balance, deficit, donorBalance };
}

async function topUpSubscription(chain: CNetwork, amount: bigint): Promise<void> {
  const { publicClient, walletClient } = getFallbackClients(chain, donorAccount);
  const { functionsRouter, linkToken, name: chainName, functionsSubIds } = chain;
  const subId = functionsSubIds[0];
  try {
    const subIdHex = parseInt(subId, 10).toString(16).padStart(2, "0").padStart(64, "0");
    const hash = await walletClient.writeContract({
      address: linkToken,
      abi: linkTokenAbi,
      functionName: "transferAndCall",
      args: [functionsRouter, amount, `0x${subIdHex}`],
    });

    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });

    log(
      `Topped up subscription ${subId} with ${formatEther(amount)} LINK. Tx: ${hash} Gas used: ${cumulativeGasUsed}`,
      "topUpSubscription",
      chainName,
    );
  } catch (error) {
    err(`Error topping up subscription ${subId} on ${chainName}: ${error}`, "topUpSubscription");
  }
}

async function ensureCLFSubscriptionBalances(isTestnet: boolean, autoTopUp: boolean): Promise<void> {
  const chains = isTestnet ? testnetChains : mainnetChains;

  try {
    const subscriptionPromises = chains.map(chain => checkSubscriptionBalance(chain));
    const subscriptionInfos = await Promise.all(subscriptionPromises);

    const displayedBalances = subscriptionInfos.map(info => ({
      chain: info.chain.name,
      subId: info.chain.functionsSubIds[0],
      balance: formatEther(info.balance),
      deficit: formatEther(info.deficit),
      donorBalance: formatEther(info.donorBalance),
    }));

    console.log("\nCLF Subscription Balances:");
    console.table(displayedBalances);

    const totalDeficit = subscriptionInfos.reduce((sum, info) => sum + info.deficit, BigInt(0));

    if (totalDeficit > BigInt(0)) {
      if (autoTopUp) {
        console.log(`Auto top-up enabled. Proceeding to top-up a total of ${formatEther(totalDeficit)} LINK.`);
        for (const info of subscriptionInfos) {
          if (info.deficit > BigInt(0)) {
            await topUpSubscription(info.chain, info.deficit);
          }
        }
      } else {
        const answer = await prompt(
          `Do you want to perform top-ups for a total of ${formatEther(totalDeficit)} LINK? (y/n): `,
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
  .addFlag("y", "Auto top-up")
  .setAction(async taskArgs => {
    await ensureCLFSubscriptionBalances(taskArgs.testnet, taskArgs.y);
  });

export default ensureCLFSubscriptionBalances;
