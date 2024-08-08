import load from "../../../utils/load";
import { getEnvVar } from "../../../utils/getEnvVar";
import CNetworks, { networkEnvKeys, networkTypes } from "../../../constants/CNetworks";
import log, { err } from "../../../utils/log";
import { mainnetChains, testnetChains } from "../liveChains";
import { viemReceiptConfig } from "../../../constants/deploymentVariables";
import { getFallbackClients } from "../../utils/getViemClients";

async function setConceroProxySender(hre) {
  const chain = CNetworks[hre.network.name];
  const { name: chainName, viemChain, url, type } = chain;
  const clients = getFallbackClients(chain);
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroChildPool.sol/ConceroChildPool.json");
  if (!chainName) throw new Error("Chain name not found");
  const chains = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const dstChain of chains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");
    const dstConceroAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[dstChainName]}`);
    const dstConceroPoolAddress =
      dstChain.chainId === CNetworks.base.chainId || dstChain.chainId === CNetworks.baseSepolia.chainId
        ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dstChainName]}`)
        : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChainName]}`);
    const conceroPoolAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chainName]}`);

    try {
      const setSenderHash = await walletClient.writeContract({
        address: conceroPoolAddress,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, dstConceroAddress, 1n],
        abi,
        account,
        viemChain,
      });

      const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
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
        gas: 1_000_000n,
      });

      const { cumulativeGasUsed: setPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setPoolHash,
      });

      log(
        `Set ${chainName}:${conceroPoolAddress} pool[${dstChainName}:${dstConceroPoolAddress}]. Gas used: ${setPoolGasUsed.toString()}`,
        "setConceroContractSender",
      );
    } catch (error) {
      err(
        `Error setting ${conceroPoolAddress} sender[${dstChainName}:${dstConceroAddress}]`,
        "setConceroContractSender",
        chainName,
      );
      console.error(error);
    }
  }
}

async function addPoolsToAllChains(hre) {
  const chain = CNetworks[hre.network.name];
  const { name: chainName, viemChain, type } = chain;
  const clients = getFallbackClients(chain);
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroChildPool.sol/ConceroChildPool.json");
  if (!chainName) throw new Error("Chain name not found");
  const chains = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const dstChain of chains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    const poolAddressToAdd =
      dstChain.chainId === CNetworks.base.chainId || dstChain.chainId === CNetworks.baseSepolia.chainId
        ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dstChain.name]}`)
        : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChain.name]}`);

    try {
      if (!dstChainName) throw new Error("Destination chain name not found");
      if (!dstChainSelector) throw new Error("Destination chain selector not found");

      const conceroPoolAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[chainName]}`);

      const { request: setPoolReq } = await publicClient.simulateContract({
        address: conceroPoolAddress,
        functionName: "setPools",
        args: [dstChainSelector, poolAddressToAdd],
        abi,
        account,
        viemChain,
        gas: 1_000_000n,
      });
      const setPoolHash = await walletClient.writeContract(setPoolReq);
      const { cumulativeGasUsed: setPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setPoolHash,
      });

      err(`Added pool ${poolAddressToAdd}. Gas used: ${setPoolGasUsed.toString()}`, "addPoolsToAllChains", chainName);
    } catch (error) {
      console.error(error);
    }
  }
}

export async function setChildProxyVariables(hre) {
  await setConceroProxySender(hre);
  await addPoolsToAllChains(hre);
}
