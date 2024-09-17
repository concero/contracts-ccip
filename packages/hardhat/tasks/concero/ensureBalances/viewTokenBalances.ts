import { mainnetChains, testnetChains } from "../../../constants/liveChains";
import { err, getEnvAddress, getEnvVar, getFallbackClients } from "../../../utils";
import { task } from "hardhat/config";
import { erc20Abi, formatUnits } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import { ProxyEnum } from "../../../constants/deploymentVariables";
import { networkEnvKeys } from "../../../constants";
import { BalanceInfo } from "./types";

const tokensToMonitor = [
  { symbol: "USDC", decimals: 6 },
  // Add more tokens here as needed
];

async function checkTokenBalance(
  chain: CNetwork,
  contractType: ProxyEnum,
  symbol: string,
  tokenDecimals: number,
): Promise<BalanceInfo> {
  const { publicClient } = getFallbackClients(chain);
  const [contractAddress, contractAlias] = getEnvAddress(contractType, chain.name);
  const tokenAddress = getEnvVar(`${symbol}_${networkEnvKeys[chain.name]}`);

  try {
    const balance = await publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [contractAddress],
    });

    return {
      chainName: chain.name,
      contractAddress,
      contractAlias,
      symbol,
      tokenDecimals,
      balance,
    };
  } catch (error) {
    err(`Error checking ${symbol} balance for ${contractAlias} on ${chain.name}: ${error}`, "checkTokenBalance");
  }
}

async function monitorTokenBalances(isTestnet: boolean): Promise<BalanceInfo[]> {
  const chains = isTestnet ? testnetChains : mainnetChains;
  const balancePromises: Promise<BalanceInfo>[] = [];

  for (const chain of Object.values(chains)) {
    for (const token of tokensToMonitor) {
      balancePromises.push(checkTokenBalance(chain, ProxyEnum.infraProxy, token.symbol, token.decimals));
    }
  }

  const balanceInfos = await Promise.all(balancePromises);

  console.log("\nToken Balances for Monitored Contracts:");
  const displayedBalanceInfos = balanceInfos.map(info => ({
    Contract: info.contractAlias,
    Chain: info.chainName,
    Balance: formatUnits(info.balance, info.tokenDecimals),
    Symbol: info.symbol,
  }));

  console.table(displayedBalanceInfos);

  const tokenTotals: { [key: string]: bigint } = {};
  for (const info of balanceInfos) {
    tokenTotals[info.symbol] = (tokenTotals[info.symbol] || BigInt(0)) + info.balance;
  }

  console.log("\nTotal Amount for Each Token:");
  console.table(
    Object.entries(tokenTotals).map(([symbol, total]) => ({
      Symbol: symbol,
      TotalAmount: formatUnits(total, tokensToMonitor.find(t => t.symbol === symbol)?.decimals || 18),
    })),
  );

  return balanceInfos;
}

task("view-token-balances", "View token balances for infraProxy contracts")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await monitorTokenBalances(taskArgs.testnet);
  });

export default monitorTokenBalances;
