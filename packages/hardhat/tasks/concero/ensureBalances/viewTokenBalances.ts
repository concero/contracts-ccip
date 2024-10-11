import { mainnetChains, ProxyEnum, testnetChains } from "../../../constants";
import { err, getEnvAddress } from "../../../utils";
import { task } from "hardhat/config";
import { formatUnits } from "viem";
import { type CNetwork } from "../../../types/CNetwork";

const BASEURL = "https://api.concero.io/api";
const IGNORE_SYMBOLS = ["LINK", "LINK.e"];

interface TokenBalance {
  _id: string;
  address: string;
  chain_id: string;
  __v: number;
  decimals: number;
  is_popular: boolean;
  logoURI: string;
  name: string;
  priceUsd: number;
  providers: Array<{
    name: string;
    symbol: string;
    _id: string;
  }>;
  symbol: string;
  balance: string; // Assuming balance is a string representation of a number
}

async function fetchBalances(chain: CNetwork, contractAddress: string): Promise<TokenBalance[]> {
  const url = `${BASEURL}/balances?wallet_address=${contractAddress}&chain_id=${chain.chainId}`;

  try {
    const response = await fetch(url, {
      headers: {
        "Accept-Encoding": "identity",
      },
    });

    if (!response.ok) {
      throw new Error(`API request failed with status ${response.status}`);
    }

    const jsonResponse = await response.json();
    const data: TokenBalance[] = jsonResponse.data[chain.chainId];

    return data;
  } catch (error) {
    err(`Error fetching balances for ${contractAddress} on ${chain.name}: ${error}`, "fetchBalances");
    return [];
  }
}

async function monitorTokenBalances(isTestnet: boolean): Promise<TokenBalance[]> {
  const chains = isTestnet ? testnetChains : mainnetChains;
  const allBalanceInfos: TokenBalance[] = [];

  const promises = Object.values(chains).map(async chain => {
    const [contractAddress, contractAlias] = getEnvAddress(ProxyEnum.infraProxy, chain.name);

    try {
      const chainBalances = await fetchBalances(chain, contractAddress);
      return { chainBalances, chain, contractAlias, contractAddress };
    } catch (error) {
      err(`Error processing balances for ${contractAlias} on ${chain.name}: ${error}`, "monitorTokenBalances");
      return null; // Handle errors appropriately
    }
  });

  const results = await Promise.all(promises);

  for (const result of results) {
    if (result) {
      const { chainBalances, chain, contractAlias } = result;

      // Process chainBalances
      const displayedBalances = chainBalances
        .filter(token => !IGNORE_SYMBOLS.includes(token.symbol))
        .map(token => {
          const balanceBigInt = BigInt(token.balance);
          const balanceFormatted = Number(formatUnits(balanceBigInt, token.decimals));
          const valueUsd = balanceFormatted * token.priceUsd;
          return {
            Contract: contractAlias,
            Chain: chain.name,
            Symbol: token.symbol,
            Balance: balanceFormatted.toString(),
            ValueUSD: valueUsd,
          };
        })
        .filter(token => token.ValueUSD >= 1)
        .sort((a, b) => b.ValueUSD - a.ValueUSD)
        .map(token => ({
          Contract: token.Contract,
          Chain: token.Chain,
          Symbol: token.Symbol,
          Balance: token.Balance,
          ValueUSD: token.ValueUSD.toFixed(2),
        }));

      console.log(`\nToken Balances for ${chain.name}:`);
      console.table(displayedBalances);

      allBalanceInfos.push(...chainBalances);
    }
  }

  // Calculate and display total amounts per token across all chains
  const tokenTotals: { [symbol: string]: { totalBalance: bigint; totalValueUsd: number } } = {};

  for (const token of allBalanceInfos) {
    if (IGNORE_SYMBOLS.includes(token.symbol)) continue;

    const balanceBigInt = BigInt(token.balance);
    const balanceFormatted = Number(formatUnits(balanceBigInt, token.decimals));
    const valueUsd = balanceFormatted * token.priceUsd;

    if (!tokenTotals[token.symbol]) {
      tokenTotals[token.symbol] = { totalBalance: balanceBigInt, totalValueUsd: valueUsd };
    } else {
      tokenTotals[token.symbol].totalBalance += balanceBigInt;
      tokenTotals[token.symbol].totalValueUsd += valueUsd;
    }
  }

  console.log("\nTotal Amount for Each Token Across All Chains (Tokens >= $1):");
  const totalTokensDisplay = Object.entries(tokenTotals)
    .filter(([_, totals]) => totals.totalValueUsd >= 1)
    .sort(([, a], [, b]) => b.totalValueUsd - a.totalValueUsd)
    .map(([symbol, totals]) => {
      const decimals = allBalanceInfos.find(t => t.symbol === symbol)?.decimals || 18;
      return {
        Symbol: symbol,
        TotalBalance: formatUnits(totals.totalBalance, decimals),
        TotalValueUSD: totals.totalValueUsd.toFixed(2),
      };
    });
  console.table(totalTokensDisplay);

  return allBalanceInfos;
}

task("view-token-balances", "View token balances for infraProxy contracts")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await monitorTokenBalances(taskArgs.testnet);
  });

export default monitorTokenBalances;
