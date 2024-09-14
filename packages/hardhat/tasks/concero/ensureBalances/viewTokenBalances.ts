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
  chainName: string;
  contractAddress: string;
  contractAlias: string;
  symbol: string;
  balance: bigint;
  tokenDecimals: number;
}

const tokensToMonitor = [
  { symbol: "USDC", decimals: 6 },
  // Add more tokens here as needed
];

async function checkTokenBalance(
  chain: CNetwork,
  contractType: ProxyType,
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
      balancePromises.push(checkTokenBalance(chain, "infraProxy", token.symbol, token.decimals));
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
