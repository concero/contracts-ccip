import { getEnvAddress } from "../../utils/getEnvVar";
import CNetworks from "../../constants/CNetworks";
import { privateKeyToAccount } from "viem/accounts";
import log, { err } from "../../utils/log";
import { task } from "hardhat/config";
import { getFallbackClients } from "../../utils/getViemClients";
import { DeploymentPrefixes, ProxyType, viemReceiptConfig } from "../../constants/deploymentVariables";
import { formatGas } from "../../utils/formatting";

export async function upgradeProxyImplementation(hre, proxyType: ProxyType, shouldPause: boolean) {
  const { name: chainName } = hre.network;
  const chainId = hre.network.config.chainId;
  const { viemChain } = CNetworks[chainName];

  let implementationKey: keyof DeploymentPrefixes;

  if (shouldPause) {
    implementationKey = "pause";
  } else if (proxyType === "infraProxy") {
    implementationKey = "orchestrator";
  } else if (proxyType === "childPoolProxy") {
    implementationKey = "childPool";
  } else if (proxyType === "parentPoolProxy") {
    implementationKey = "parentPool";
  } else {
    err(`Proxy type ${proxyType} not found`, "upgradeProxyImplementation", chainName);
    return;
  }

  const { abi: proxyAdminAbi } = await import(
    "../../artifacts/contracts/transparentProxy/ConceroProxyAdmin.sol/ConceroProxyAdmin.json"
  );

  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getFallbackClients(CNetworks[chainName], viemAccount);

  const [conceroProxy, conceroProxyAlias] = getEnvAddress(proxyType, chainName);
  const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, chainName);
  const [newImplementation, newImplementationAlias] = getEnvAddress(implementationKey, chainName);
  const [pauseDummy, pauseAlias] = getEnvAddress("pause", chainName);

  const implementation = shouldPause ? pauseDummy : newImplementation;
  const implementationAlias = shouldPause ? pauseAlias : newImplementationAlias;

  const txHash = await walletClient.writeContract({
    address: proxyAdmin,
    abi: proxyAdminAbi,
    functionName: "upgradeAndCall",
    account: viemAccount,
    args: [conceroProxy, implementation, "0x"],
    chain: viemChain,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: txHash });

  log(
    `Upgraded via ${proxyAdminAlias}: ${conceroProxyAlias}.implementation -> ${implementationAlias}. Gas : ${formatGas(cumulativeGasUsed)}, hash: ${txHash}`,
    `setProxyImplementation : ${proxyType}`,
    chainName,
  );
}
export default {};

task("upgrade-proxy-implementation", "Upgrades the proxy implementation")
  .addFlag("pause", "Pause the proxy before upgrading", false)
  .addParam("proxytype", "The type of the proxy to upgrade", undefined)
  .setAction(async taskArgs => {
    await upgradeProxyImplementation(hre, taskArgs.proxytype, taskArgs.pause);
  });
