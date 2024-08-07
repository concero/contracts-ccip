import { CNetwork } from "../../../types/CNetwork";
import { getClients } from "../../utils/getViemClients";
import { getEnvVar } from "../../../utils/getEnvVar";
import { networkEnvKeys } from "../../../constants/CNetworks";
import { ethersV6CodeUrl, parentPoolJsCodeUrl } from "../../../constants/functionsJsCodeUrls";
import { Address } from "viem";
import log from "../../../utils/log";
import getHashSum from "../../../utils/getHashSum";
import load from "../../../utils/load";
import { getEthersSignerAndProvider } from "../../utils/getEthersSignerAndProvider";
import { SecretsManager } from "@chainlink/functions-toolkit";
import { liveChains } from "../liveChains";
import env from "../../../types/env";

async function setParentPoolJsHashes(deployableChain: CNetwork, abi: any) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = deployableChain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const parentPoolProxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[srcChainName]}`);
    const parentPoolJsCode = await (await fetch(parentPoolJsCodeUrl)).text();
    const ethersCode = await (await fetch(ethersV6CodeUrl)).text();

    const setHash = async (hash: string, functionName: string) => {
      const setHashHash = await walletClient.writeContract({
        address: parentPoolProxyAddress as Address,
        abi,
        functionName,
        account,
        args: [hash],
        chain: dcViemChain,
        gas: 1_000_000n,
      });
      const { cumulativeGasUsed: setHashGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setHashHash,
      });

      log(
        `Set ${srcChainName}:${parentPoolProxyAddress} jshash[${hash}]. Gas used: ${setHashGasUsed.toString()}`,
        functionName,
      );
    };

    await setHash(getHashSum(parentPoolJsCode), "setHashSum");
    await setHash(getHashSum(ethersCode), "setEthersHashSum");
  } catch (error) {
    log(`Error ${error?.message}`, "setHashSum");
  }
}

async function setParentPoolCap(chain: CNetwork, abi: any) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = chain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const parentPoolProxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[srcChainName]}`) as Address;
    const poolCap = 100_000n * 10n ** 6n;

    const { request: setCapReq } = await publicClient.simulateContract({
      address: parentPoolProxyAddress,
      abi,
      functionName: "setPoolCap",
      account,
      args: [poolCap],
      chain: dcViemChain,
    });

    const setCapHash = await walletClient.writeContract(setCapReq);
    const { cumulativeGasUsed: setCapGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setCapHash,
    });
  } catch (error) {
    log(`Error ${error?.message}`, "setPoolCap");
  }
}

async function setParentPoolSecretsVersion(chain: CNetwork, abi: any, slotId: number) {
  try {
    const {
      functionsRouter: dcFunctionsRouter,
      functionsDonIdAlias: dcFunctionsDonIdAlias,
      functionsGatewayUrls: dcFunctionsGatewayUrls,
      url: dcUrl,
      viemChain: dcViemChain,
      name: dcName,
    } = chain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const parentPoolProxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dcName]}`) as Address;
    const { signer: dcSigner } = getEthersSignerAndProvider(dcUrl);

    const secretsManager = new SecretsManager({
      signer: dcSigner,
      functionsRouterAddress: dcFunctionsRouter,
      donId: dcFunctionsDonIdAlias,
    });
    await secretsManager.initialize();

    const { result } = await secretsManager.listDONHostedEncryptedSecrets(dcFunctionsGatewayUrls);
    const nodeResponse = result.nodeResponses[0];
    if (!nodeResponse.rows) return log(`No secrets found for ${dcName}.`, "updateContract");

    const rowBySlotId = nodeResponse.rows.find(row => row.slot_id === slotId);
    if (!rowBySlotId) return log(`No secrets found for ${dcName} at slot ${slotId}.`, "updateContract");

    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
      address: parentPoolProxyAddress,
      abi,
      functionName: "setDonHostedSecretsVersion",
      account,
      args: [rowBySlotId.version],
      chain: dcViemChain,
    });
    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);

    const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setDstConceroContractHash,
    });

    log(
      `Set ${dcName}:${parentPoolProxyAddress} donHostedSecretsVersion[${rowBySlotId.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
      "setDonHostedSecretsVersion",
    );
  } catch (error) {
    log(`Error ${error?.message}`, "setDonHostedSecretsVersion");
  }
}

async function setParentPoolSecretsSlotId(chian: CNetwork, abi: any, slotId: number) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = chian;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const parentPoolProxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[srcChainName]}`) as Address;

    const { request } = await publicClient.simulateContract({
      address: parentPoolProxyAddress,
      abi,
      functionName: "setDonHostedSecretsSlotId",
      account,
      args: [BigInt(slotId)],
      chain: dcViemChain,
    });

    const hash = await walletClient.writeContract(request);
    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });

    log(
      `Set ${srcChainName}:${parentPoolProxyAddress} donHostedSecretsSlotId[${slotId}]. Gas used: ${cumulativeGasUsed.toString()}`,
      "setDonHostedSecretsSlotId",
    );
  } catch (error) {
    log(`Error ${error?.message}`, "setDonHostedSecretsSlotId");
  }
}

async function setConceroContractSenders(chain: CNetwork, abi: any) {
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");
    const dstConceroContract = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address;
    const conceroPoolAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chainName]}` as keyof env) as Address;
    const childPool = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address;

    const setSender = async (sender: Address) => {
      const { request: setSenderReq } = await publicClient.simulateContract({
        address: conceroPoolAddress,
        functionName: "setConceroContractSender",
        args: [dstChainSelector, sender, 1n],
        abi,
        account,
        viemChain,
      });
      const setSenderHash = await walletClient.writeContract(setSenderReq);
      const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setSenderHash,
      });
      log(
        `Set ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${sender}]. Gas used: ${setSenderGasUsed.toString()}`,
        "setSenders",
      );
    };

    await setSender(dstConceroContract);
    await setSender(childPool);
  }
}

async function setPools(chain: CNetwork, abi: any) {
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    try {
      if (dstChain.chainId === chain.chainId) continue;

      const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
      if (!dstChainName) throw new Error("Destination chain name not found");
      const conceroPoolAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chainName]}` as keyof env);
      const dstPoolAddress = getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChainName]}` as keyof env);

      const { request: setReceiverReq } = await publicClient.simulateContract({
        address: conceroPoolAddress,
        functionName: "setPools",
        args: [dstChainSelector, dstPoolAddress, false],
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
        "setPools",
      );
    } catch (error) {
      log(`Error ${error?.message}`, "setPools");
    }
  }
}

async function deletePendingRequest(chain: CNetwork, abi, reqId: string) {
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  if (!chainName) throw new Error("Chain name not found");

  const conceroPoolAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chainName]}` as keyof env);
  const { request: deletePendingReq } = await publicClient.simulateContract({
    address: conceroPoolAddress,
    functionName: "deletePendingWithdrawRequest",
    args: [reqId],
    abi,
    account,
    viemChain,
  });
  const deletePendingHash = await walletClient.writeContract(deletePendingReq);
  const { cumulativeGasUsed: deletePendingGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: deletePendingHash,
  });
  log(`Delete pending requests. Gas used: ${deletePendingGasUsed.toString()}`, "deletePendingWithdrawRequest");
}

async function getPendingRequest(chain: CNetwork, abi: any) {
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  if (!chainName) throw new Error("Chain name not found");
  const conceroPoolAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chainName]}` as keyof env);

  const pendingRequest = await publicClient.readContract({
    address: conceroPoolAddress,
    abi,
    functionName: "getPendingWithdrawRequest",
    args: ["0x1637A2cafe89Ea6d8eCb7cC7378C023f25c892b6"],
    chain: viemChain,
  });

  console.log(pendingRequest);
}

async function removePool(chain: CNetwork, abi: any, networkName: string) {
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  if (!chainName) throw new Error("Chain name not found");

  const parentPoolAddress = getEnvVar(`PARENT_POOL_PROXY_BASE_SEPOLIA` as keyof env);
  const chainSelectorToRemove = getEnvVar(`CL_CCIP_CHAIN_SELECTOR_${networkEnvKeys[networkName]}` as keyof env);

  const deletePoolHash = await walletClient.writeContract({
    address: parentPoolAddress,
    abi,
    functionName: "removePools",
    args: [chainSelectorToRemove],
    account,
    viemChain,
    gas: 1_000_000n,
  });

  const { cumulativeGasUsed: deletePoolGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: deletePoolHash,
  });

  log(`Remove pool ${networkName}. Gas used: ${deletePoolGasUsed.toString()}`, "removePool");
}

export async function setParentPoolVariables(chain: CNetwork, slotId: number) {
  const { abi: ParentPoolAbi } = await load("../artifacts/contracts/ConceroParentPool.sol/ConceroParentPool.json");

  await setParentPoolSecretsVersion(chain, ParentPoolAbi, slotId);
  await setParentPoolSecretsSlotId(chain, ParentPoolAbi, slotId);

  await setParentPoolJsHashes(chain, ParentPoolAbi);

  await setParentPoolCap(chain, ParentPoolAbi); // once
  await setPools(chain, ParentPoolAbi); // once
  await setConceroContractSenders(chain, ParentPoolAbi); // once
}
