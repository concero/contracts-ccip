import { networkEnvKeys } from "../../constants/CNetworks";
import { CNetwork } from "../../types/CNetwork";
import { getClients } from "../utils/switchChain";
import load from "../../utils/load";
import { getEnvVar } from "../../utils/getEnvVar";
import log from "../../utils/log";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import { SecretsManager } from "@chainlink/functions-toolkit";
import { Address } from "viem";
import getHashSum from "../../utils/getHashSum";
import { liveChains } from "./liveChains";
import { dstJsCodeUrl, ethersV6CodeUrl, srcJsCodeUrl } from "../../constants/functionsJsCodeUrls";

export async function setContractVariables(liveChains: CNetwork[], deployableChains: CNetwork[], slotId: number) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  for (const deployableChain of deployableChains) {
    await setDexSwapAllowedRouters(deployableChain, abi); // once
    await setDstConceroPools(deployableChain, abi);
    await setDonHostedSecretsVersion(deployableChain, slotId, abi);
    await setDonSecretsSlotId(deployableChain, slotId, abi);
    await addMessengerToAllowlist(deployableChain, abi); // once
    await setJsHashes(deployableChain, abi, liveChains);
  }
}

export async function setConceroProxyDstContracts(liveChains: CNetwork[]) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  for (const chain of liveChains) {
    const { viemChain, url, name } = chain;
    try {
      const srcConceroProxyAddress = getEnvVar(`CONCEROPROXY_${networkEnvKeys[name]}`);
      const { walletClient, publicClient, account } = getClients(viemChain, url);

      for (const dstChain of liveChains) {
        const { name: dstName, chainSelector: dstChainSelector } = dstChain;
        if (dstName !== name) {
          const dstProxyContract = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dstName]}`);

          const { request: setDstConceroContractReq } = await publicClient.simulateContract({
            address: srcConceroProxyAddress as Address,
            abi,
            functionName: "setConceroContract",
            account,
            args: [dstChainSelector, dstProxyContract],
            chain: viemChain,
          });
          const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
          const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: setDstConceroContractHash,
          });
          log(
            `Set ${name}:${srcConceroProxyAddress} dstConceroContract[${dstName}, ${dstProxyContract}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
            "setConceroProxyDstContracts",
          );
        }
      }
    } catch (error) {
      log(`Error for ${name}: ${error.message}`, "setConceroProxyDstContracts");
    }
  }
}

export async function setDonHostedSecretsVersion(deployableChain: CNetwork, slotId: number, abi: any) {
  // todo: assert slotid = current slotid in the contract, otherwise skip setDonHostedSecretsVersion
  //todo: Set DonHostedSecrets slotId in case necessary
  const {
    functionsRouter: dcFunctionsRouter,
    functionsDonIdAlias: dcFunctionsDonIdAlias,
    functionsGatewayUrls: dcFunctionsGatewayUrls,
    url: dcUrl,
    viemChain: dcViemChain,
    name: dcName,
  } = deployableChain;
  try {
    const conceroProxy = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dcName]}`);
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);

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
      address: conceroProxy as Address,
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
      `Set ${dcName}:${conceroProxy} donHostedSecretsVersion[${rowBySlotId.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
      "setDonHostedSecretsVersion",
    );
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "setDonHostedSecretsVersion");
  }
}

async function addMessengerToAllowlist(deployableChain: CNetwork, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
  const conceroProxy = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dcName]}`);
  const messengerWallet = getEnvVar("MESSENGER_ADDRESS");

  try {
    const { request: addToAllowlistReq } = await publicClient.simulateContract({
      address: conceroProxy,
      abi,
      functionName: "setConceroMessenger",
      account,
      args: [messengerWallet, 1n],
      chain: dcViemChain,
    });
    const addToAllowlistHash = await walletClient.writeContract(addToAllowlistReq);
    const { cumulativeGasUsed: addToAllowlistGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: addToAllowlistHash,
    });
    log(
      `Set ${dcName}:${conceroProxy} allowlist[${messengerWallet}]. Gas used: ${addToAllowlistGasUsed.toString()}`,
      "setConceroMessenger",
    );
  } catch (error) {
    if (error.message.includes("Address already in allowlist")) {
      log(`${messengerWallet} was already added to allowlist of ${conceroProxy}`, "setConceroMessenger");
    } else {
      log(`Error for ${dcName}: ${error.message}`, "setConceroMessenger");
    }
  }
}

async function setJsHashes(deployableChain: CNetwork, abi: any, liveChains: CNetwork[]) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = deployableChain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const conceroProxyAddress = getEnvVar(`CONCEROPROXY_${networkEnvKeys[srcChainName]}`);
    const conceroSrcCode = await (await fetch(srcJsCodeUrl)).text();
    const conceroDstCode = await (await fetch(dstJsCodeUrl)).text();
    const ethersCode = await (await fetch(ethersV6CodeUrl)).text();

    const setHash = async (hash: string, functionName: string) => {
      const { request: setHashReq } = await publicClient.simulateContract({
        address: conceroProxyAddress as Address,
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
        `Set ${srcChainName}:${conceroProxyAddress} jshash[${hash}]. Gas used: ${setHashGasUsed.toString()}`,
        functionName,
      );
    };

    await setHash(getHashSum(conceroDstCode), "setDstJsHashSum");
    await setHash(getHashSum(conceroSrcCode), "setSrcJsHashSum");
    await setHash(getHashSum(ethersCode), "setEthersHashSum");
  } catch (error) {
    log(`Error ${error.message}`, "setHashSum");
  }
}

export async function setDstConceroPools(deployableChain: CNetwork, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
  const conceroProxy = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dcName]}`);

  try {
    for (const chain of liveChains) {
      const { name: dstChainName, chainSelector: dstChainSelector } = chain;
      const dstConceroPool = getEnvVar(`CONCEROPOOL_${networkEnvKeys[dstChainName]}`);
      const { request: setDstConceroPoolReq } = await publicClient.simulateContract({
        address: conceroProxy as Address,
        abi,
        functionName: "setDstConceroPool",
        account,
        args: [dstChainSelector, dstConceroPool],
        chain: dcViemChain,
      });
      const setDstConceroPoolHash = await walletClient.writeContract(setDstConceroPoolReq);
      const { cumulativeGasUsed: setDstConceroPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setDstConceroPoolHash,
      });
      log(
        `Set ${dcName}:${conceroProxy} dstConceroPool[${dstChainName}:${dstConceroPool}]. Gas used: ${setDstConceroPoolGasUsed.toString()}`,
        "setDstConceroPool",
      );
    }
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "setDstConceroPool");
  }
}

export async function setDonSecretsSlotId(deployableChain: CNetwork, slotId: number, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
  const conceroProxy = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dcName]}`);

  try {
    const { request: setDonSecretsSlotIdReq } = await publicClient.simulateContract({
      address: conceroProxy as Address,
      abi,
      functionName: "setDonHostedSecretsSlotID",
      account,
      args: [slotId],
      chain: dcViemChain,
    });
    const setDonSecretsSlotIdHash = await walletClient.writeContract(setDonSecretsSlotIdReq);
    const { cumulativeGasUsed: setDonSecretsSlotIdGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setDonSecretsSlotIdHash,
    });
    log(
      `Set ${dcName}:${conceroProxy} donSecretsSlotId[${slotId}]. Gas used: ${setDonSecretsSlotIdGasUsed.toString()}`,
      "setDonHostedSecretsSlotID",
    );
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "setDonHostedSecretsSlotID");
  }
}

export async function setDexSwapAllowedRouters(deployableChain: CNetwork, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const conceroProxy = getEnvVar(`CONCEROPROXY_${networkEnvKeys[dcName]}`);
  const allowedRouter = "0xF8908a808F1c04396B16A5a5f0A14064324d0EdA";
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);

  try {
    const { request: setDexRouterReq } = await publicClient.simulateContract({
      address: conceroProxy as Address,
      abi,
      functionName: "setDexRouterAddress",
      account,
      args: [allowedRouter, 1n],
      chain: dcViemChain,
    });
    const setDexRouterHash = await walletClient.writeContract(setDexRouterReq);
    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setDexRouterHash,
    });
    log(
      `Set ${dcName}:${conceroProxy} dexRouterAddress[${allowedRouter}]. Gas used: ${setDexRouterGasUsed.toString()}`,
      "setDexRouterAddress",
    );
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "setDexRouterAddress");
  }
}
