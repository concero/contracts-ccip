import { conceroChains, mainnetChains, testnetChains } from "../concero/liveChains";
import { getFallbackClients } from "../utils/getViemClients";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { parseUnits } from "viem";
import { type CNetwork, CNetworkNames } from "../../types/CNetwork";
import log, { err } from "../../utils/log";
import { type BalanceInfo, type ERC20BalanceInfo } from "./types";
import { getEnvVar } from "../../utils/getEnvVar";
import readline from "readline";
import { viemReceiptConfig } from "../../constants/deploymentVariables";
import { networkEnvKeys } from "../../constants/CNetworks";
import ierc20Abi from "@chainlink/contracts/abi/v0.8/IERC20.json";

const LINK = (network: CNetworkNames) => getEnvVar(`LINK_${networkEnvKeys[network]}`);
const USDC = (network: CNetworkNames) => getEnvVar(`USDC_${networkEnvKeys[network]}`);

const donorAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);

const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

async function checkERC20Balance(
  wallet: string,
  token: string,
  targetAmount: bigint,
  publicClient: any,
): Promise<ERC20BalanceInfo> {
  const balance = await publicClient.getERC20Balance({ address: wallet, token });
  const deficit = balance < targetAmount ? targetAmount - balance : BigInt(0);

  return {
    address: wallet,
    token,
    balance: balance.toString(),
    target: targetAmount.toString(),
    deficit: deficit.toString(),
  };
}

async function topUpERC20Wallet(
  wallet: string,
  token: string,
  amount: bigint,
  publicClient: any,
  walletClient: any,
): Promise<void> {
  try {
    const hash = await walletClient.sendERC20Transaction({ to: wallet, token, value: amount });
    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });
    log(
      `Topped up ${wallet} with ${amount.toString()} of token ${token} on ${publicClient.chain.name}. Tx: ${hash}. Gas used: ${setDexRouterGasUsed}`,
      "topUpERC20Wallet",
    );
  } catch (error) {
    err(
      `Error topping up ${wallet} with token ${token} on ${publicClient.chain.name}: ${error}`,
      "topUpERC20Wallet",
      walletClient.chain.name,
    );
  }
}

async function collectChainInfo(chain: CNetwork): Promise<[BalanceInfo[], ERC20BalanceInfo[]]> {
  const { publicClient } = getFallbackClients(chain, donorAccount);

  const donorBalances: BalanceInfo[] = [];
  const erc20WalletInfos: ERC20BalanceInfo[] = [];

  const chainContracts = contracts[chain.name] || [];
  for (const contract of chainContracts) {
    for (const { token, targetAmount } of contract.tokens) {
      const erc20WalletInfo = await checkERC20Balance(contract.address, token, targetAmount, publicClient);
      erc20WalletInfos.push(erc20WalletInfo);

      // Check donor's ERC20 balance for each token
      const donorTokenBalance = await publicClient.readContract({
        address: token,
        abi: ierc20Abi,
        functionName: "balanceOf",
        args: [donorAccount.address],
      });

      donorBalances.push({
        chain,
        address: donorAccount.address,
        token,
        balance: donorTokenBalance.toString(),
        target: "N/A",
        deficit: "N/A",
      });
    }
  }

  return [donorBalances, erc20WalletInfos];
}

async function performTopUps(erc20WalletBalances: ERC20BalanceInfo[], donorAccount: any): Promise<void> {
  for (const erc20WalletInfo of erc20WalletBalances) {
    const deficit = BigInt(erc20WalletInfo.deficit);

    if (deficit > BigInt(0)) {
      const { publicClient, walletClient } = getFallbackClients(erc20WalletInfo.chain, donorAccount);
      await topUpERC20Wallet(erc20WalletInfo.address, erc20WalletInfo.token, deficit, publicClient, walletClient);
    }
  }
}

async function ensureERC20Balances(isTestnet: boolean) {
  const generateContracts = (networks: CNetwork[]) => {
    return networks.reduce(
      (acc, chain) => {
        acc[chain.name] = [
          {
            address: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[chain.name]}`),
            tokens: [
              { token: LINK(chain.name), targetAmount: parseUnits("100", 18) },
              { token: USDC(chain.name), targetAmount: parseUnits("1000", 6) },
            ],
          },
          {
            address: getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chain.name]}`),
            tokens: [
              { token: LINK(chain.name), targetAmount: parseUnits("100", 18) },
              { token: USDC(chain.name), targetAmount: parseUnits("1000", 6) },
            ],
          },
        ];
        return acc;
      },
      {} as Record<string, { address: string; tokens: { token: string; targetAmount: bigint }[] }[]>,
    );
  };

  const contracts = {
    ...generateContracts(conceroChains.testnet.parentPool),
    ...generateContracts(conceroChains.testnet.childPools),
    ...generateContracts(conceroChains.testnet.infra),
  };

  const donorBalances: BalanceInfo[] = [];
  const erc20WalletBalances: ERC20BalanceInfo[] = [];

  try {
    const chains = isTestnet ? testnetChains : mainnetChains;

    for (const chain of chains) {
      const [donorInfos, erc20WalletInfos] = await collectChainInfo(chain);
      donorBalances.push(...donorInfos);
      erc20WalletBalances.push(...erc20WalletInfos);
    }

    const displayedDonorBalances = donorBalances.map(info => ({
      chain: info.chain.name,
      address: info.address,
      token: info.token,
      balance: info.balance,
    }));

    const displayedERC20WalletBalances = erc20WalletBalances.map(info => ({
      address: info.address,
      token: info.token,
      balance: info.balance,
      target: info.target,
      deficit: info.deficit,
    }));

    console.log("\nDonor Balances:");
    console.table(displayedDonorBalances);

    console.log("\nERC20 Wallet Balances:");
    console.table(displayedERC20WalletBalances);

    const totalERC20Deficit = erc20WalletBalances.reduce((sum, info) => sum + parseFloat(info.deficit), 0);

    if (totalERC20Deficit > 0) {
      const answer = await prompt(
        `Do you want to perform top-ups for a total of ${totalERC20Deficit.toFixed(6)} ERC20 tokens? (y/n): `,
      );
      if (answer.toLowerCase() === "y") {
        await performTopUps(erc20WalletBalances, donorAccount);
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

task("ensure-erc20-balances", "Ensure balances of wallets")
  .addFlag("testnet")
  .setAction(async taskArgs => {
    await ensureERC20Balances(taskArgs.testnet);
  });

export default ensureERC20Balances;
