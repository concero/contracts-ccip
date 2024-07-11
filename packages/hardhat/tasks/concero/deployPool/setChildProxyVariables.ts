import { getClients } from "../../utils/getViemClients";
import load from "../../../utils/load";
import { getEnvVar } from "../../../utils/getEnvVar";
import chains from "../../../constants/CNetworks";
import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import env from "../../../types/env";
import { Address } from "viem";
import log from "../../../utils/log";
import { liveChains } from "../liveChains";

async function setConceroProxySender(hre) {
  const chain = chains[hre.network.name];
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroChildPool.sol/ConceroChildPool.json");
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");
    const dstConceroAddress = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address;
    const dstConceroPoolAddress =
      dstChain.chainId === CNetworks.base.chainId || dstChain.chainId === CNetworks.baseSepolia.chainId
        ? (getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address)
        : (getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address);
    const conceroPoolAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chainName]}` as keyof env) as Address;

    try {
      const gasPrice = await publicClient.getGasPrice();

      const setSenderHash = await walletClient.writeContract({
        address: conceroPoolAddress,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, dstConceroAddress, 1n],
        abi,
        account,
        viemChain,
        gasPrice,
      });

      const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setSenderHash,
      });

      log(
        `Set ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${dstConceroAddress}]. Gas used: ${setSenderGasUsed.toString()}`,
        "setConceroContractSender",
      );

      const setPoolHash = await walletClient.writeContract({
        address: conceroPoolAddress,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, dstConceroPoolAddress, 1n],
        abi,
        account,
        viemChain,
        gasPrice,
      });

      const { cumulativeGasUsed: setPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setPoolHash,
      });

      log(
        `Set ${chainName}:${conceroPoolAddress} pool[${dstChainName}:${dstConceroPoolAddress}]. Gas used: ${setPoolGasUsed.toString()}`,
        "setConceroContractSender",
      );
    } catch (error) {
      log(
        `Error setting ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${dstConceroAddress}]`,
        "setConceroContractSender",
      );
      console.error(error);
    }
  }
}

export async function setChildProxyVariables(hre) {
  await setConceroProxySender(hre);
}
