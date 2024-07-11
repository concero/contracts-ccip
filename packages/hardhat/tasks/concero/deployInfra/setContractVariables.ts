import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import { CNetwork } from "../../../types/CNetwork";
import { getClients } from "../../utils/getViemClients";
import load from "../../../utils/load";
import { getEnvVar } from "../../../utils/getEnvVar";
import log from "../../../utils/log";
import { getEthersSignerAndProvider } from "../../utils/getEthersSignerAndProvider";
import { SecretsManager } from "@chainlink/functions-toolkit";
import { Address } from "viem";
import getHashSum from "../../../utils/getHashSum";
import { liveChains } from "../liveChains";
import { ethersV6CodeUrl, infraDstJsCodeUrl, infraSrcJsCodeUrl } from "../../../constants/functionsJsCodeUrls";

const resetLastGasPrices = async (deployableChain: CNetwork, chains: CNetwork[], abi: any) => {
  const conceroProxyAddress = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[deployableChain.name]}`);
  const { walletClient, publicClient, account } = getClients(deployableChain.viemChain, deployableChain.url);

  for (const chain of chains) {
    const { chainSelector } = chain;

    const resetGasPricesHash = await walletClient.writeContract({
      address: conceroProxyAddress as Address,
      abi: abi,
      functionName: "setLasGasPrices",
      args: [chainSelector!, 0n],
      account,
      chain: deployableChain.viemChain,
    });

    const { cumulativeGasUsed: resetGasPricesGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: resetGasPricesHash,
    });

    log(
      `Reset last gas prices for ${deployableChain.name}:${conceroProxyAddress}. Gas used: ${resetGasPricesGasUsed.toString()}`,
      "resetLastGasPrices",
    );
  }
};

export async function setConceroProxyDstContracts(liveChains: CNetwork[]) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  for (const chain of liveChains) {
    const { viemChain, url, name } = chain;
    const srcConceroProxyAddress = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[name]}`);
    const { walletClient, publicClient, account } = getClients(viemChain, url);

    for (const dstChain of liveChains) {
      try {
        const { name: dstName, chainSelector: dstChainSelector } = dstChain;
        if (dstName !== name) {
          const dstProxyContract = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dstName]}`);

          // const gasPrice = await publicClient.getGasPrice();

          // const { request: setDstConceroContractReq } = await publicClient.simulateContract({
          //   address: srcConceroProxyAddress as Address,
          //   abi,
          //   functionName: "setConceroContract",
          //   account,
          //   args: [dstChainSelector, dstProxyContract],
          //   chain: viemChain,
          // });
          // const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);

          const setDstConceroContractHash = await walletClient.writeContract({
            address: srcConceroProxyAddress as Address,
            abi,
            functionName: "setConceroContract",
            account,
            args: [dstChainSelector, dstProxyContract],
            chain: viemChain,
          });

          const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: setDstConceroContractHash,
            timeout: 0,
          });
          log(
            `Set ${name}:${srcConceroProxyAddress} dstConceroContract[${dstName}, ${dstProxyContract}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
            "setConceroProxyDstContracts",
          );
        }
      } catch (error) {
        log(`Error for ${name}: ${error.message}`, "setConceroProxyDstContracts");
      }
    }
  }
}

export async function setDonHostedSecretsVersion(deployableChain: CNetwork, slotId: number, abi: any) {
  const {
    functionsRouter: dcFunctionsRouter,
    functionsDonIdAlias: dcFunctionsDonIdAlias,
    functionsGatewayUrls: dcFunctionsGatewayUrls,
    url: dcUrl,
    viemChain: dcViemChain,
    name: dcName,
  } = deployableChain;
  try {
    const conceroProxy = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dcName]}`) as Address;
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
      address: conceroProxy,
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

async function setJsHashes(deployableChain: CNetwork, abi: any) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = deployableChain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const conceroProxyAddress = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[srcChainName]}`);
    const conceroSrcCode = await (await fetch(infraSrcJsCodeUrl)).text();
    const conceroDstCode = await (await fetch(infraDstJsCodeUrl)).text();
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
  const conceroProxy = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dcName]}`);

  try {
    for (const chain of liveChains) {
      const { name: dstChainName, chainSelector: dstChainSelector } = chain;
      const dstConceroPool =
        chain === CNetworks.base || chain === CNetworks.baseSepolia
          ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[dstChainName]}`)
          : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[dstChainName]}`);
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
  const conceroProxy = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dcName]}`);

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

const allowedRouters: Record<string, Address> = {
  "137": "0xE592427A0AEce92De3Edee1F18E0157C05861564",
  "8453": "0x2626664c2603336E57B271c5C0b26F421741e481",
  "42161": "0xE592427A0AEce92De3Edee1F18E0157C05861564",
  "43114": "0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE",
};

export async function setDexSwapAllowedRouters(deployableChain: CNetwork, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const conceroProxy = getEnvVar(`CONCERO_PROXY_${networkEnvKeys[dcName]}`);

  if (!deployableChain.chainId) {
    return log(`No chainId for ${dcName}`, "setDexRouterAddress");
  }

  const allowedRouter = allowedRouters[deployableChain.chainId];
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

export async function setContractVariables(
  liveChains: CNetwork[],
  deployableChains: CNetwork[],
  slotId: number,
  uploadsecrets: boolean,
) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  for (const deployableChain of deployableChains) {
    await setDexSwapAllowedRouters(deployableChain, abi); // once
    await setDstConceroPools(deployableChain, abi); // once
    // if (uploadsecrets) {
    await setDonHostedSecretsVersion(deployableChain, slotId, abi);
    await setDonSecretsSlotId(deployableChain, slotId, abi);
    // }

    await setJsHashes(deployableChain, abi);
  }
}
