import { task } from "hardhat/config";
import { execSync } from "child_process";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroPool from "../../deploy/04_ConceroPool";
import { liveChains } from "./liveChains";
import { CNetwork } from "../../types/CNetwork";
import { getClients } from "../utils/switchChain";
import CNetworks, { networkEnvKeys } from "../../constants/CNetworks";
import { getEnvVar } from "../../utils/getEnvVar";
import load from "../../utils/load";
import log from "../../utils/log";
import env from "../../types/env";

async function setOrchestrator(chain: CNetwork, clients) {
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  const { name: chainName, viemChain } = chain;
  if (!chainName) throw new Error("Chain name not found");
  const orchestrator = getEnvVar(`CONCEROCCIP_${networkEnvKeys[chainName]}` as keyof env);
  const conceroPool = getEnvVar(`CONCEROPOOL_${networkEnvKeys[chainName]}` as keyof env);

  const { request: setOrchestratorReq } = await publicClient.simulateContract({
    address: conceroPool,
    functionName: "setConceroOrchestrator",
    args: [orchestrator],
    abi,
    account,
    viemChain,
  });
  const setOrchestratorHash = await walletClient.writeContract(setOrchestratorReq);
  const { cumulativeGasUsed: setOrchestratorGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: setOrchestratorHash,
  });

  log(
    `Set ${chainName}:${conceroPool} orchestrator[${orchestrator}]. Gas used: ${setOrchestratorGasUsed.toString()}`,
    "setOrchestrator",
  );
}

async function setMessenger(chain: CNetwork, clients) {
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  const { name: chainName, viemChain } = chain;
  if (!chainName) throw new Error("Chain name not found");
  const messengerWallet = getEnvVar("MESSENGER_ADDRESS");
  const conceroPool = getEnvVar(`CONCEROPOOL_${networkEnvKeys[chainName]}` as keyof env);

  const { request: setMessengerReq } = await publicClient.simulateContract({
    address: conceroPool,
    functionName: "setMessenger",
    args: [messengerWallet],
    abi,
    account,
    viemChain,
  });
  const setMessengerHash = await walletClient.writeContract(setMessengerReq);
  const { cumulativeGasUsed: setMessengerGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: setMessengerHash,
  });

  log(
    `Set ${chainName}:${conceroPool} messenger[${messengerWallet}]. Gas used: ${setMessengerGasUsed.toString()}`,
    "setMessenger",
  );
}

async function setSupportedTokens(chain: CNetwork, clients) {
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  const { name: chainName, viemChain } = chain;
  if (!chainName) throw new Error("Chain name not found");
  const conceroPool = getEnvVar(`CONCEROPOOL_${networkEnvKeys[chainName]}` as keyof env);

  const supportedToken = getEnvVar(`USDC_${networkEnvKeys[chainName]}` as keyof env);
  const { request: setSupportedTokensReq } = await publicClient.simulateContract({
    address: conceroPool,
    functionName: "setSupportedToken",
    args: [supportedToken, 1n],
    abi,
    account,
    viemChain,
  });
  const setSupportedTokensHash = await walletClient.writeContract(setSupportedTokensReq);
  const { cumulativeGasUsed: setSupportedTokensGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: setSupportedTokensHash,
  });

  log(
    `Set ${chainName}:${conceroPool} supportedTokens[${supportedToken}]. Gas used: ${setSupportedTokensGasUsed.toString()}`,
    "setSupportedToken",
  );
}

async function setConceroContractSenders(chain: CNetwork, clients) {
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  const { name: chainName, viemChain } = chain;
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    const dstConceroContract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[dstChainName]}` as keyof env);
    const conceroPoolAddress = getEnvVar(`CONCEROPOOL_${networkEnvKeys[chainName]}` as keyof env);

    const { request: setSenderReq } = await publicClient.simulateContract({
      address: conceroPoolAddress,
      functionName: "setConceroContractSender",
      args: [dstChainSelector, dstConceroContract, 1n],
      abi,
      account,
      viemChain,
    });
    const setSenderHash = await walletClient.writeContract(setSenderReq);
    const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setSenderHash,
    });
    log(
      `Set ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${dstConceroContract}]. Gas used: ${setSenderGasUsed.toString()}`,
      "setSenders",
    );
  }
}

async function setReceivers(chain: CNetwork, clients) {
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  const { name: chainName, viemChain } = chain;
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    const dstPoolAddress = getEnvVar(`CONCEROPOOL_${networkEnvKeys[dstChainName]}` as keyof env);
    const conceroPoolAddress = getEnvVar(`CONCEROPOOL_${networkEnvKeys[chainName]}` as keyof env);

    const { request: setReceiverReq } = await publicClient.simulateContract({
      address: conceroPoolAddress,
      functionName: "setConceroPoolReceiver",
      args: [dstChainSelector, dstPoolAddress],
      abi,
      account,
      viemChain,
    });
    const setReceiverHash = await walletClient.writeContract(setReceiverReq);
    const { cumulativeGasUsed: setReceiverGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setReceiverHash,
    });
    log(
      `Set ${chainName}:${conceroPoolAddress} receiver[${dstChainName}:${dstPoolAddress}]. Gas used: ${setReceiverGasUsed.toString()}`,
      "setReceivers",
    );
  }
}

async function setPoolVariables(deployableChains: CNetwork[]) {
  for (const chain of deployableChains) {
    const { viemChain, url } = chain;
    const clients = getClients(viemChain, url);

    await setOrchestrator(chain, clients);
    await setMessenger(chain, clients);
    await setSupportedTokens(chain, clients);

    await setConceroContractSenders(chain, clients);
    await setReceivers(chain, clients);
  }
}

task("deploy-pool", "Deploy the concero pool")
  .addFlag("skipdeploy", "Skip deployment")
  .setAction(async taskArgs => {
    try {
      const hre: HardhatRuntimeEnvironment = require("hardhat");
      const { name } = hre.network;
      let deployableChains: CNetwork[] = liveChains;

      if (name !== "localhost" && name !== "hardhat") {
        deployableChains = [CNetworks[name]];
      }

      if (taskArgs.skipdeploy) {
        console.log("Skipping deployment");
      } else {
        execSync("yarn compile", { stdio: "inherit" });
        await deployConceroPool(hre);
      }

      await setPoolVariables(deployableChains);
    } catch (e) {
      console.error(e);
    }
  });

export default {};
