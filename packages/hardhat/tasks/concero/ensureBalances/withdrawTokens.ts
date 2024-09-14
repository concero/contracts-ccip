import { task } from "hardhat/config";
import monitorTokenBalances, { BalanceInfo } from "./viewTokenBalances";
import { getFallbackClients } from "../../../utils/getViemClients";
import { getEnvVar } from "../../../utils/getEnvVar";
import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import load from "../../../utils/load";
import { viemReceiptConfig } from "../../../constants/deploymentVariables";
import log from "../../../utils/log";

async function withdrawTokens(isTestnet: boolean) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");
  // Step 1: Get balances
  const balances: BalanceInfo[] = await monitorTokenBalances(isTestnet);

  // Step 2: Filter out tokens with a balance greater than zero
  const tokensWithBalance = balances.filter(info => Number(info.balance) > 0);

  if (tokensWithBalance.length === 0) {
    console.log("No tokens available to withdraw.");
    return;
  }

  // Step 3: Prompt the user to confirm the withdrawal
  console.log("\nTokens available for withdrawal:");
  console.table(tokensWithBalance);

  const proceed = await new Promise(resolve => {
    const rl = require("readline").createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    rl.question("Do you want to proceed with the withdrawal? (y/n) ", (answer: string) => {
      rl.close();
      resolve(answer.trim().toLowerCase() === "y");
    });
  });

  if (!proceed) {
    console.log("Withdrawal cancelled.");
    return;
  }

  // Step 4: Withdraw the tokens
  for (const token of tokensWithBalance) {
    const { chainName, contractAddress, symbol, balance } = token;
    const chain = CNetworks[chainName];
    const viemChain = chain.viemChain;

    const tokenAddress = getEnvVar(`${symbol}_${networkEnvKeys[chainName]}`);
    const amountToWithdraw = balance; // Assuming we're withdrawing the full balance

    const { publicClient, walletClient, account } = getFallbackClients(chain);
    const { request: withdrawReq } = await publicClient.simulateContract({
      address: contractAddress,
      abi,
      functionName: "withdraw",
      account,
      args: [account.address, tokenAddress, amountToWithdraw],
      chain: viemChain,
    });

    const hash = await walletClient.writeContract(withdrawReq);
    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });

    log(`Withdrawn ${balance} ${symbol}(Gas Used: ${cumulativeGasUsed})`, "withdrawToken", chain.name);
  }
}

task("withdraw-tokens", "Withdraw tokens from infraProxy contracts")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await withdrawTokens(taskArgs.testnet);
  });

export default withdrawTokens;
