import { task } from "hardhat/config";
import chains, { networkEnvKeys } from "../../../constants/cNetworks";
import { CNetwork } from "../../../types/CNetwork";
import { getEnvVar, getFallbackClients } from "../../../utils";
import { Address, erc20Abi } from "viem";
import log, { err } from "../../../utils/log";
import { viemReceiptConfig } from "../../../constants";

const getBalance = async (tokenAddress: Address, account: Address, chain: CNetwork) => {
  const { publicClient } = getFallbackClients(chain);

  return await publicClient.readContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [account],
  });
};

const contractKeys = {
  conceroproxy: "CONCERO_INFRA_PROXY",
  parentpoolproxy: "PARENT_POOL_PROXY",
  childpoolproxy: "CHILD_POOL_PROXY",
};

type ContractType = keyof typeof contractKeys;

const withdrawToken = async (chain: CNetwork, tokenAddress: Address, contractType: ContractType, amount: string) => {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = chain;
  const { walletClient, publicClient, account } = getFallbackClients(chain);
  const conceroProxy = getEnvVar(`${contractKeys[contractType]}_${networkEnvKeys[dcName]}`);
  const { abi } = await import("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");
  const amountToWithdraw = BigInt(amount);
  try {
    const usdBalance = await getBalance(tokenAddress, conceroProxy, chain);

    if (usdBalance < amountToWithdraw) {
      log(
        `Not enough balance to withdraw. Balance: ${usdBalance}, Amount to withdraw: ${amountToWithdraw}`,
        "withdrawToken",
      );
      return;
    }

    const { request: withdrawReq } = await publicClient.simulateContract({
      address: conceroProxy,
      abi,
      functionName: "withdraw",
      account,
      args: [account.address, tokenAddress, amountToWithdraw],
      chain: dcViemChain,
    });
    const hash = await walletClient.writeContract(withdrawReq);
    const { cumulativeGasUsed: setDonSecretsSlotIdGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });
    log(
      `Withdrawn from ${dcName}:${conceroProxy}: ${amountToWithdraw}. Gas used: ${setDonSecretsSlotIdGasUsed.toString()}`,
      "withdrawToken",
    );
  } catch (error) {
    err(`${error.message}`, "setDonHostedSecretsSlotID", dcName);
  }
};

const depositToken = async (chain: CNetwork, tokenAddress: Address, contractType: ContractType, amount: string) => {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = chain;
  const { walletClient, publicClient, account } = getFallbackClients(chain);
  const recipientAddress = getEnvVar(`${contractKeys[contractType]}_${networkEnvKeys[dcName]}`);
  const amountToDeposit = BigInt(amount);

  try {
    const accountBalance = await getBalance(tokenAddress, account.address, chain);
    if (accountBalance < amountToDeposit) {
      log(
        `Not enough balance to deposit. Balance: ${accountBalance}, Amount to deposit: ${amountToDeposit}`,
        "depositToken",
      );
      return;
    }

    const { request: depositReq } = await publicClient.simulateContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: "transfer",
      account,
      args: [recipientAddress, amountToDeposit],
      chain: dcViemChain,
    });

    const hash = await walletClient.writeContract(depositReq);
    const { cumulativeGasUsed: depositGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash,
    });
    log(
      `Deposited to ${dcName}:${recipientAddress}: ${amountToDeposit}. Gas used: ${depositGasUsed.toString()}`,
      "depositToken",
    );
  } catch (error) {
    console.error(error);
    err(`${error.message}`, "depositToken", dcName);
  }
};
task("deposit-infra-proxy", "Deposits the token to the proxy contract")
  .addParam("tokenaddress", "Token Address")
  .addParam("contracttype", "Contract Type")
  .addParam("amount", "Amount to deposit")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    const { contracttype, tokenaddress, amount } = taskArgs;
    if (live) {
      await depositToken(chains[name], tokenaddress, contracttype, amount);
    }
  });

// todo: can be withdraw with --infra-proxy flag to be applied to multiple contracts
task("withdraw-infra-proxy", "Withdraws the token from the proxy contract")
  .addParam("tokenaddress", "Token Address")
  .addParam("contracttype", "Contract Type")
  .addParam("amount", "Amount to withdraw")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    const { contracttype, tokenaddress, amount } = taskArgs;
    if (live) {
      await withdrawToken(chains[name], tokenaddress, contracttype, amount);
    }
  });

export default {};
