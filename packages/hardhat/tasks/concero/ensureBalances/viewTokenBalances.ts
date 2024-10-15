import { mainnetChains, ProxyEnum, testnetChains } from "../../../constants";
import { err, getEnvAddress } from "../../../utils";
import { task } from "hardhat/config";
import { formatUnits } from "viem";
import { type CNetwork } from "../../../types/CNetwork";

const BASEURL = "https://api.concero.io/api";
const IGNORE_SYMBOLS = ["LINK", "LINK.e", "LINK(ERC677)", "TITAN"];
const MIN_TOTAL_VALUE_USD = 10;

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
  balance: string;
  totalValueUsd?: number;
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

async function monitorTokenBalances(isTestnet: boolean): Promise<{ [chainName: string]: TokenBalance[] }> {
  const chains = isTestnet ? testnetChains : mainnetChains;
  const balancesByChain: { [chainName: string]: TokenBalance[] } = {};

  const promises = Object.values(chains).map(async chain => {
    const [contractAddress, contractAlias] = getEnvAddress(ProxyEnum.infraProxy, chain.name);

    try {
      let chainBalances = await fetchBalances(chain, contractAddress);

      // Filter out ignored tokens
      chainBalances = chainBalances.filter(token => !IGNORE_SYMBOLS.includes(token.symbol));

      // Calculate totalValueUsd and append to each token
      chainBalances = chainBalances.map(token => {
        const balanceBigInt = BigInt(token.balance);
        const balanceFormatted = Number(formatUnits(balanceBigInt, token.decimals));
        const totalValueUsd = balanceFormatted * token.priceUsd;
        return {
          ...token,
          totalValueUsd,
        };
      });

      // Filter out tokens with totalValueUsd < 1
      chainBalances = chainBalances.filter(token => token.totalValueUsd >= MIN_TOTAL_VALUE_USD);

      // Sort chainBalances by totalValueUsd descending
      chainBalances = chainBalances.sort((a, b) => b.totalValueUsd - a.totalValueUsd);

      // Assign balances to the chain name
      balancesByChain[chain.name] = chainBalances;

      // Prepare data for display
      const displayedBalances = chainBalances.map(token => ({
        Contract: contractAlias,
        Chain: chain.name,
        Symbol: token.symbol,
        Balance: Number(formatUnits(BigInt(token.balance), token.decimals)).toString(),
        ValueUSD: token.totalValueUsd?.toFixed(2),
      }));

      console.log(`\nToken Balances for ${chain.name}:`);
      console.table(displayedBalances);
    } catch (error) {
      err(`Error processing balances for ${contractAlias} on ${chain.name}: ${error}`, "monitorTokenBalances");
    }
  });

  await Promise.all(promises);

  // Calculate and display total amounts per token across all chains
  const allBalanceInfos = Object.values(balancesByChain).flat();
  const tokenTotals: { [symbol: string]: { totalBalance: bigint; totalValueUsd: number } } = {};

  for (const token of allBalanceInfos) {
    const balanceBigInt = BigInt(token.balance);
    if (!tokenTotals[token.symbol]) {
      tokenTotals[token.symbol] = {
        totalBalance: balanceBigInt,
        totalValueUsd: token.totalValueUsd || 0,
      };
    } else {
      tokenTotals[token.symbol].totalBalance += balanceBigInt;
      tokenTotals[token.symbol].totalValueUsd += token.totalValueUsd || 0;
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

  return balancesByChain;
}

task("view-token-balances", "View token balances for infraProxy contracts")
  .addFlag("testnet", "Use testnet instead of mainnet")
  .setAction(async taskArgs => {
    await monitorTokenBalances(taskArgs.testnet);
  });

export default monitorTokenBalances;
