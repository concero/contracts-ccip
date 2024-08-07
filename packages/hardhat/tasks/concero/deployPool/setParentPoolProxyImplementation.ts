import { getEnvVar } from "../../../utils/getEnvVar";
import { networkEnvKeys } from "../../../constants/CNetworks";
import { parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { getFallbackClients } from "../../utils/getViemClients";
import log from "../../../utils/log";
import { CNetwork } from "../../../types/CNetwork";
import { viemReceiptConfig } from "../../../constants/deploymentVariables";

export async function setParentPoolProxyImplementation(hre, liveChains: CNetwork[]) {
  const { name: chainName } = hre.network;
  const conceroProxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chainName]}`);
  const chainId = hre.network.config.chainId;
  const chain = liveChains.find(c => {
    return c.chainId?.toString() === chainId.toString();
  });

  if (!chain) {
    throw new Error(`Chain not found: ${chainId}`);
  }

  const { viemChain } = chain;
  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getFallbackClients(chain, viemAccount);
  const parentPoolAddress = getEnvVar(`PARENT_POOL_${networkEnvKeys[chainName]}`);

  const txHash = await walletClient.writeContract({
    address: conceroProxyAddress,
    abi: parseAbi(["function upgradeToAndCall(address, bytes calldata) external payable"]),
    functionName: "upgradeToAndCall",
    account: viemAccount,
    args: [parentPoolAddress, "0x"],
    chain: viemChain,
    gas: 500_000n,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: txHash });

  log(
    `Upgrade to Parent Pool implementation: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`,
    "setProxyImplementation",
  );
}
