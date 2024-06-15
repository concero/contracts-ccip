import { getEnvVar } from "../../utils/getEnvVar";
import { networkEnvKeys } from "../../constants/CNetworks";
import { CNetwork } from "../../types/CNetwork";
import { getClients } from "../utils/switchChain";
import { privateKeyToAccount } from "viem/accounts";
import load from "../../utils/load";
import { Address } from "viem";
import log from "../../utils/log";

export async function setProxyImplementation(hre, liveChains: CNetwork[]) {
  const { abi: conceroProxyAbi } = await load("../artifacts/contracts/ConceroProxy.sol/ConceroProxy.json");
  const { name: chainName } = hre.network;
  const conceroProxyAddress = getEnvVar(`CONCEROPROXY_${networkEnvKeys[chainName]}`);
  const chainId = hre.network.config.chainId;
  const { viemChain } = liveChains.find(chain => chain.chainId === chainId);
  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getClients(viemChain, undefined, viemAccount);
  const conceroOrchestratorAddress = getEnvVar(`CONCERO_ORCHESTRATOR_${networkEnvKeys[chainName]}`);

  const { request } = await publicClient.simulateContract({
    address: conceroProxyAddress as Address,
    abi: conceroProxyAbi,
    functionName: "upgradeTo",
    account: viemAccount,
    args: [conceroOrchestratorAddress],
    chain: viemChain,
  });

  const txHash = await walletClient.writeContract(request);
  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash: txHash });

  log(`Upgrade to CCIP implementation: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`, "setProxyImplementation");
}
