import { getEnvVar } from "../../utils/getEnvVar";
import { networkEnvKeys } from "../../constants/CNetworks";
import { CNetwork } from "../../types/CNetwork";
import { getClients } from "../utils/switchChain";
import { privateKeyToAccount } from "viem/accounts";
import { Address, parseAbi } from "viem";
import log from "../../utils/log";

export async function setProxyImplementation(hre, liveChains: CNetwork[]) {
  const { name: chainName } = hre.network;
  const conceroProxyAddress = getEnvVar(`CONCEROPROXY_${networkEnvKeys[chainName]}`) as Address;
  const chainId = hre.network.config.chainId;
  const { viemChain } = liveChains.find(chain => chain.chainId === chainId);
  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getClients(viemChain, undefined, viemAccount);
  const conceroOrchestratorAddress = getEnvVar(`CONCERO_ORCHESTRATOR_${networkEnvKeys[chainName]}`) as Address;

  // const { request } = await publicClient.simulateContract({
  //   address: conceroProxyAddress as Address,
  //   abi: parseAbi(["function upgradeToAndCall(address newImplementation, bytes calldata data) external"]),
  //   functionName: "upgradeToAndCall",
  //   account: viemAccount,
  //   args: [conceroOrchestratorAddress, "0x"],
  //   chain: viemChain,
  // });
  // const txHash = await walletClient.writeContract(request);

  const txHash = await walletClient.writeContract({
    address: conceroProxyAddress,
    abi: parseAbi(["function upgradeToAndCall(address, bytes calldata) external payable"]),
    functionName: "upgradeToAndCall",
    account: viemAccount,
    args: [conceroOrchestratorAddress, "0x"],
    chain: viemChain,
    gas: 500_000n,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash: txHash });

  log(`Upgrade to CCIP implementation: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`, "setProxyImplementation");
}
