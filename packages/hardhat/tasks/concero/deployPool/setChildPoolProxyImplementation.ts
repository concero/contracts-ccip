import { CNetwork } from "../../../types/CNetwork";
import { getEnvVar } from "../../../utils/getEnvVar";
import { networkEnvKeys } from "../../../constants/CNetworks";
import { Address, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { getClients } from "../../utils/switchChain";
import log from "../../../utils/log";

export async function setChildPoolProxyImplementation(hre, liveChains: CNetwork[]) {
  const { name: chainName } = hre.network;
  const conceroProxyAddress = getEnvVar(`CHILDPROXY_${networkEnvKeys[chainName]}`) as Address;
  const chainId = hre.network.config.chainId;
  const { viemChain } = liveChains.find(chain => chain.chainId === chainId);
  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getClients(viemChain, undefined, viemAccount);
  const childPoolAddress = getEnvVar(`CHILDPOOL_${networkEnvKeys[chainName]}`) as Address;

  const txHash = await walletClient.writeContract({
    address: conceroProxyAddress,
    abi: parseAbi(["function upgradeToAndCall(address, bytes calldata) external payable"]),
    functionName: "upgradeToAndCall",
    account: viemAccount,
    args: [childPoolAddress, "0x"],
    chain: viemChain,
    gas: 500_000n,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash: txHash });

  log(`Upgrade to CCIP implementation: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`, "setProxyImplementation");
}
