import { getEnvVar } from "../../utils/getEnvVar";
import CNetworks, { networkEnvKeys } from "../../constants/CNetworks";
import { getClients } from "../utils/getViemClients";
import { privateKeyToAccount } from "viem/accounts";
import log from "../../utils/log";
import { task } from "hardhat/config";
import { ProxyType } from "../../deploy/11_TransparentProxy";

export async function upgradeProxyImplementation(hre, proxyType: ProxyType, shouldPause: boolean) {
  const { name: chainName } = hre.network;
  const chainId = hre.network.config.chainId;
  const { viemChain, url } = CNetworks[chainName];

  let envKey: string;
  let implementationKey: string;

  switch (proxyType) {
    case ProxyType.infra:
      envKey = `CONCERO_INFRA_PROXY`;
      implementationKey = `CONCERO_ORCHESTRATOR`;
      break;
    case ProxyType.parentPool:
      envKey = `PARENT_POOL_PROXY`;
      implementationKey = `PARENT_POOL`;
      break;
    case ProxyType.childPool:
      envKey = `CHILD_POOL_PROXY`;
      implementationKey = `CHILD_POOL`;
      break;
    default:
      throw new Error("Invalid ProxyType");
  }

  const { abi: proxyAdminAbi } = await import(
    "../../artifacts/contracts/transparentProxy/ProxyAdmin.sol/ProxyAdmin.json"
  );

  if (!viemChain) {
    log(`Chain ${chainId} not found in live chains`, "upgradeProxyImplementation");
    return;
  }

  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getClients(viemChain, url, viemAccount);

  const conceroProxy = getEnvVar(`${envKey}_${networkEnvKeys[chainName]}`);
  const proxyAdminContract = getEnvVar(`${envKey}_ADMIN_CONTRACT_${networkEnvKeys[chainName]}`);
  const newImplementationAddress = getEnvVar(`${implementationKey}_${networkEnvKeys[chainName]}`);
  const pauseDummy = getEnvVar(`CONCERO_PAUSE_${networkEnvKeys[chainName]}`);

  const implementation = shouldPause ? pauseDummy : newImplementationAddress;

  const txHash = await walletClient.writeContract({
    address: proxyAdminContract,
    abi: proxyAdminAbi,
    functionName: "upgradeAndCall",
    account: viemAccount,
    args: [conceroProxy, implementation, "0x"],
    chain: viemChain,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash: txHash, timeout: 0 });

  log(`Upgrade Proxy Implementation: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`, "setProxyImplementation");
}
export default {};

task("upgrade-proxy-implementation", "Upgrades the proxy implementation")
  .addFlag("pause", "Pause the proxy before upgrading", false)
  .addParam("proxytype", "The type of the proxy to upgrade")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    if (name !== "localhost" && name !== "hardhat") {
      await upgradeProxyImplementation(hre, parseInt(taskArgs.proxytype), taskArgs.pause);
    }
  });
