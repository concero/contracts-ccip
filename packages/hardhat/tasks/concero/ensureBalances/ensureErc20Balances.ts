import { conceroChains, ProxyEnum, viemReceiptConfig } from "../../../constants";
import { getEnvAddress, getFallbackClients } from "../../../utils";
import { privateKeyToAccount } from "viem/accounts";
import { task } from "hardhat/config";
import { erc20Abi, formatEther, parseEther } from "viem";
import { type CNetwork } from "../../../types/CNetwork";
import log, { err } from "../../../utils/log";
import readline from "readline";
import checkERC20Balance from "./checkERC20Balance";
import { type BalanceInfo } from "./types";

const donorAccount = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const prompt = (question: string): Promise<string> => new Promise(resolve => rl.question(question, resolve));

const minBalances: Record<ProxyEnum, bigint> = {
  parentPoolProxy: parseEther("7"),
  childPoolProxy: parseEther("1"),
  infraProxy: parseEther("2"),
};

async function checkChainBalance(chain: CNetwork, contractType: ProxyEnum): Promise<BalanceInfo> {
  const { linkToken } = chain;
  const minBalance = minBalances[contractType];

  const [address, alias] = getEnvAddress(contractType, chain.name);

  const { balance } = await checkERC20Balance(chain, linkToken, address);
  const deficit = balance < minBalance ? minBalance - balance : BigInt(0);
  const { balance: donorBalance } = await checkERC20Balance(chain, linkToken, donorAccount.address);

  return { chain, address, alias, balance, deficit, donorBalance, contractType };
}

async function topUpERC20(chain: CNetwork, amount: bigint, contractAddress, contractAlias): Promise<void> {
  const { publicClient, walletClient } = getFallbackClients(chain, donorAccount);
  const { linkToken, name: chainName } = chain;

  try {
    const hash = await walletClient.writeContract({
      address: linkToken,
      abi: erc20Abi,
      functionName: "transfer",
      args: [contractAddress, amount],
    });

    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });

    log(
      `Topped up ${contractAlias} with ${formatEther(amount)} LINK. Tx: ${hash} Gas used: ${cumulativeGasUsed}`,
      "topUpERC20",
      chainName,
    );
  } catch (error) {
    err(`Error topping up ${contractAlias} on ${chainName}: ${error}`, "topUpERC20");
  }
}

async function ensureERC20Balances(isTestnet: boolean) {
  const networkType = isTestnet ? "testnet" : "mainnet";
  const chains = conceroChains[networkType];
  const balanceInfos: BalanceInfo[] = [];

  try {
    for (const [chainType, chainList] of Object.entries(chains)) {
      const balancePromises = chainList.map(chain => checkChainBalance(chain, `${chainType}Proxy`));
      balanceInfos.push(...(await Promise.all(balancePromises)));
    }

    const displayedBalances = balanceInfos.map(info => ({
      contract: info.alias,
      chain: info.chain.name,
      balance: formatEther(info.balance),
      deficit: formatEther(info.deficit),
      donorBalance: formatEther(info.donorBalance),
    }));

    console.log("\nERC20 (LINK) Balances:");
    console.table(displayedBalances);

    const totalDeficit = balanceInfos.reduce((sum, info) => sum + info.deficit, BigInt(0));

    if (totalDeficit > BigInt(0)) {
      const answer = await prompt(
        `Do you want to perform top-ups for a total of ${formatEther(totalDeficit)} LINK? (y/n): `,
      );

      if (answer.toLowerCase() === "y") {
        for (const info of balanceInfos) {
          if (info.deficit > BigInt(0)) {
            await topUpERC20(info.chain, info.deficit, info.address, info.alias);
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

task("ensure-erc20-balances", "Ensure ERC20 (LINK) balances for Concero contracts")
  .addFlag("testnet")
  .setAction(async taskArgs => {
    await ensureERC20Balances(taskArgs.testnet);
  });

export default ensureERC20Balances;
