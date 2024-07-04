import { CNetwork } from "../../../types/CNetwork";
import { getClients } from "../../utils/switchChain";
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
    const parentPoolProxyAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[srcChainName]}`);
    const parentPoolJsCode = await (await fetch(parentPoolJsCodeUrl)).text();
    const ethersCode = await (await fetch(ethersV6CodeUrl)).text();

    const setHash = async (hash: string, functionName: string) => {
      const { request: setHashReq } = await publicClient.simulateContract({
        address: parentPoolProxyAddress as Address,
        abi,
        functionName,
        account,
        args: [hash],
        chain: dcViemChain,
      });
      const setHashHash = await walletClient.writeContract(setHashReq);
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
    const parentPoolProxyAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[srcChainName]}`) as Address;
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
    const parentPoolProxyAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[dcName]}`) as Address;
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
    const parentPoolProxyAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[srcChainName]}`) as Address;

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

async function setConceroContractSenders(chain: CNetwork) {
  const { name: chainName, viemChain, url } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    if (!dstChainSelector) throw new Error("Destination chain selector not found");
    const dstConceroContract = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dstChainName]}` as keyof env) as Address;
    const conceroPoolAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[chainName]}` as keyof env) as Address;

    const { request: setSenderReq } = await publicClient.simulateContract({
      address: conceroPoolAddress,
      functionName: "setConceroContractSender",
      args: [dstChainSelector, dstConceroContract, 1n],
      abi,
      account,
      viemChain,
    });
    const setSenderHash = await walletClient.writeContract(setSenderReq);
    const { cumulativeGasUsed: setSenderGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setSenderHash,
    });
    log(
      `Set ${chainName}:${conceroPoolAddress} sender[${dstChainName}:${dstConceroContract}]. Gas used: ${setSenderGasUsed.toString()}`,
      "setSenders",
    );
  }
}

async function setPoolsToSend(chain: CNetwork) {
  const { name: chainName, viemChain } = chain;
  const clients = getClients(viemChain, url);
  const { publicClient, account, walletClient } = clients;
  const { abi } = await load("../artifacts/contracts/ConceroPool.sol/ConceroPool.json");
  if (!chainName) throw new Error("Chain name not found");

  for (const dstChain of liveChains) {
    if (dstChain.chainId === chain.chainId) continue;

    const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
    if (!dstChainName) throw new Error("Destination chain name not found");
    const dstPoolAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[dstChainName]}` as keyof env);
    const conceroPoolAddress = getEnvVar(`PARENTPROXY_${networkEnvKeys[chainName]}` as keyof env);

    const { request: setReceiverReq } = await publicClient.simulateContract({
      address: conceroPoolAddress,
      functionName: "setPoolsToSend",
      args: [dstChainSelector, dstPoolAddress],
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
      "setPoolsToSend",
    );
  }
}

export async function setParentPoolVariables(chain: CNetwork, isSetSecretsNeeded: boolean, slotId: number) {
  const { abi: ParentPoolAbi } = await load("../artifacts/contracts/ParentPool.sol/ParentPool.json");

  await setParentPoolJsHashes(chain, ParentPoolAbi);
  await setParentPoolCap(chain, ParentPoolAbi);

  if (isSetSecretsNeeded) {
    await setParentPoolSecretsVersion(chain, ParentPoolAbi, slotId);
    await setParentPoolSecretsSlotId(chain, ParentPoolAbi, slotId);
  }

  await setConceroContractSenders(chain);
  await setPoolsToSend(chain);
}
