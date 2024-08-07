import { getEnvVar } from "../../../utils/getEnvVar";
import { networkEnvKeys } from "../../../constants/CNetworks";
import { Address, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { getClients } from "../../utils/getViemClients";
import log from "../../../utils/log";
import { CNetwork } from "../../../types/CNetwork";

export async function setParentPoolProxyImplementation(hre, liveChains: CNetwork[]) {
  const { name: chainName } = hre.network;
  const conceroProxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chainName]}`) as Address;
  const chainId = hre.network.config.chainId;
  const chain = liveChains.find(c => {
    return c.chainId?.toString() === chainId.toString();
  });

  if (!chain) {
    throw new Error(`Chain not found: ${chainId}`);
  }

  const { viemChain } = chain;
  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getClients(viemChain, undefined, viemAccount);
  const parentPoolAddress = getEnvVar(`PARENT_POOL_${networkEnvKeys[chainName]}`) as Address;

  const txHash = await walletClient.writeContract({
    address: conceroProxyAddress,
    abi: parseAbi(["function upgradeToAndCall(address, bytes calldata) external payable"]),
    functionName: "upgradeToAndCall",
    account: viemAccount,
    args: [parentPoolAddress, "0x"],
    chain: viemChain,
    gas: 500_000n,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash: txHash });

  log(
    `Upgrade to Parent Pool implementation: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`,
    "setProxyImplementation",
  );
}
