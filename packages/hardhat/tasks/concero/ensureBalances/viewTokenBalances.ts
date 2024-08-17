import { mainnetChains, testnetChains } from "../liveChains";
import { getFallbackClients } from "../../../utils/getViemClients";
import { task } from "hardhat/config";
import { erc20Abi, formatUnits } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import { err } from "../../../utils/log";
import { ProxyType } from "../../../constants/deploymentVariables";
import { getEnvAddress, getEnvVar } from "../../../utils/getEnvVar";
import { networkEnvKeys } from "../../../constants/CNetworks";

interface BalanceInfo {
  chain: string;
  contractAddress: string;
  contractAlias: string;
  tokenSymbol: string;
  balance: string;
}

const tokensToMonitor = [
  { symbol: "USDC", decimals: 6 },
  // Add more tokens here as needed
];

async function checkTokenBalance(
  chain: CNetwork,
  contractType: ProxyType,
  tokenSymbol: string,
  tokenDecimals: number,
): Promise<BalanceInfo> {
  const { publicClient } = getFallbackClients(chain);
  const [contractAddress, contractAlias] = getEnvAddress(contractType, chain.name);
  const tokenAddress = getEnvVar(`${tokenSymbol}_${networkEnvKeys[chain.name]}`);

  try {
    const balance = await publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [contractAddress],
    });

    return {
      chain: chain.name,
      address: contractAlias,
      symbol: tokenSymbol,
      balance: formatUnits(balance, tokenDecimals),
    };
  } catch (error) {
    err(`Error checking ${tokenSymbol} balance for ${contractAlias} on ${chain.name}: ${error}`, "checkTokenBalance");
    return {
      chain: chain.name,
      address: contractAlias,
      symbol: tokenSymbol,
      balance: "Error",
    };
  }
}

async function monitorTokenBalances(isTestnet: boolean) {
  const chains = isTestnet ? testnetChains : mainnetChains;

  const balancePromises: Promise<BalanceInfo>[] = [];

  for (const chain of Object.values(chains)) {
    for (const token of tokensToMonitor) {
      balancePromises.push(checkTokenBalance(chain, "infraProxy", token.symbol, token.decimals));
    }
  }

  const balanceInfos = await Promise.all(balancePromises);

  console.log("\nToken Balances for Monitored Contracts:");
  console.table(balanceInfos);

  const tokenTotals: { [key: string]: number } = {};
  for (const info of balanceInfos) {
    if (info.balance !== "Error") {
      const amount = parseFloat(info.balance);
      tokenTotals[info.symbol] = (tokenTotals[info.symbol] || 0) + amount;
    }
  }

  console.log("\nTotal Amount for Each Token:");
  console.table(
    Object.entries(tokenTotals).map(([symbol, total]) => ({
      Symbol: symbol,
      TotalAmount: total.toFixed(6),
    })),
  );
}

task("view-token-balances", "View token balances for infraProxy contracts")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await monitorTokenBalances(taskArgs.testnet);
  });

export default monitorTokenBalances;
