import { cNetworks, ProxyEnum, viemReceiptConfig } from "../../../constants";
import monitorTokenBalances from "./viewTokenBalances";
import { formatUnits } from "viem";
import { getEnvAddress, getFallbackClients, log } from "../../../utils";

async function withdrawTokens(isTestnet: boolean) {
  const { abi } = await import("../../../artifacts/contracts/InfraOrchestrator.sol/InfraOrchestrator.json");

  const balancesByChain = await monitorTokenBalances(isTestnet);

  for (const chainName in balancesByChain) {
    const chainBalances = balancesByChain[chainName];
    const chain = cNetworks[chainName];

    // Initialize contractAddress and viem clients once per chain
    const [contractAddress, contractAlias] = getEnvAddress(ProxyEnum.infraProxy, chainName);
    const viemChain = chain.viemChain;
    const { publicClient, walletClient, account } = getFallbackClients(chain);

    // Filter tokens with balance > 0
    const tokensWithBalance = chainBalances.filter(info => BigInt(info.balance) > BigInt(0));

    if (tokensWithBalance.length === 0) {
      console.log(`No tokens available to withdraw on ${chainName}.`);
      continue;
    }

    // Step 3: Prompt the user to confirm the withdrawal per chain
    console.log(`\nTokens available for withdrawal on ${chainName}:`);
    const displayedTokensWithBalance = tokensWithBalance.map(token => {
      const balanceBigInt = BigInt(token.balance);
      const balanceFormatted = formatUnits(balanceBigInt, token.decimals);
      const valueUsd = Number(balanceFormatted) * token.priceUsd;
      return {
        Chain: chainName,
        Contract: contractAlias,
        Symbol: token.symbol,
        tokenAddress: token.address,
        Balance: balanceFormatted,
        ValueUSD: valueUsd.toFixed(2),
      };
    });
    console.table(displayedTokensWithBalance);

    const proceed = await new Promise(resolve => {
      const rl = require("readline").createInterface({
        input: process.stdin,
        output: process.stdout,
      });
      rl.question(`Do you want to proceed with the withdrawal on ${chainName}? (y/n) `, (answer: string) => {
        rl.close();
        resolve(answer.trim().toLowerCase() === "y");
      });
    });

    if (!proceed) {
      console.log(`Withdrawal cancelled on ${chainName}.`);
      continue;
    }

    // Step 4: Withdraw the tokens
    for (const token of tokensWithBalance) {
      const { address, symbol, balance, decimals } = token;

      const amountToWithdraw = BigInt(balance); // Withdrawing the full balance

      const { request: withdrawReq } = await publicClient.simulateContract({
        address: contractAddress,
        abi,
        functionName: "withdraw",
        account,
        args: [account.address, address, amountToWithdraw],
        chain: viemChain,
      });

      const hash = await walletClient.writeContract(withdrawReq);
      const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash,
      });

      log(
        `Withdrawn ${formatUnits(amountToWithdraw, decimals)} ${symbol} on ${chainName} (Gas Used: ${cumulativeGasUsed})`,
        "withdrawToken",
        chain.name,
      );
    }
  }
}

task("withdraw-tokens", "Withdraw tokens from infraProxy contracts")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await withdrawTokens(taskArgs.testnet);
  });
export default withdrawTokens;
