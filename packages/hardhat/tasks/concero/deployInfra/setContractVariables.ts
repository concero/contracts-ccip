import CNetworks, { networkEnvKeys, networkTypes } from "../../../constants/CNetworks";
import { CNetwork, CNetworkNames } from "../../../types/CNetwork";
import { getFallbackClients } from "../../../utils/getViemClients";
import load from "../../../utils/load";
import { getEnvAddress, getEnvVar } from "../../../utils/getEnvVar";
import log, { err } from "../../../utils/log";
import { getEthersV5FallbackSignerAndProvider } from "../../../utils/getEthersSignerAndProvider";
import { SecretsManager } from "@chainlink/functions-toolkit";
import getHashSum from "../../../utils/getHashSum";
import { conceroChains, mainnetChains, testnetChains } from "../liveChains";
import { ethersV6CodeUrl, infraDstJsCodeUrl, infraSrcJsCodeUrl } from "../../../constants/functionsJsCodeUrls";
import { ProxyType, viemReceiptConfig } from "../../../constants/deploymentVariables";
import { formatGas, shorten } from "../../../utils/formatting";

const resetLastGasPrices = async (deployableChain: CNetwork, chains: CNetwork[], abi: any) => {
  const conceroProxyAddress = getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[deployableChain.name]}`);
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);

  for (const chain of chains) {
    const { chainSelector } = chain;

    const resetGasPricesHash = await walletClient.writeContract({
      address: conceroProxyAddress,
      abi: abi,
      functionName: "setLasGasPrices",
      args: [chainSelector!, 0n],
      account,
      chain: deployableChain.viemChain,
    });

    const { cumulativeGasUsed: resetGasPricesGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: resetGasPricesHash,
    });

    log(
      `Reset last gas prices for ${deployableChain.name}:${conceroProxyAddress}. Gas used: ${resetGasPricesGasUsed.toString()}`,
      "resetLastGasPrices",
    );
  }
};

export async function setConceroProxyDstContracts(deployableChains: CNetwork[]) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  for (const chain of deployableChains) {
    const chainsToBeSet =
      chain.type === networkTypes.mainnet ? conceroChains.mainnet.infra : conceroChains.testnet.infra;
    const { viemChain, name } = chain;
    const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, name);
    const { walletClient, publicClient, account } = getFallbackClients(chain);

    for (const dstChain of chainsToBeSet) {
      try {
        const { name: dstName, chainSelector: dstChainSelector } = dstChain;
        if (dstName !== name) {
          const [dstProxy, dstProxyAlias] = getEnvAddress(ProxyType.infraProxy, dstName);

          // const gasPrice = await publicClient.getGasPrice();

          // const { request: setDstConceroContractReq } = await publicClient.simulateContract({
          //   address: srcConceroProxyAddress ,
          //   abi,
          //   functionName: "setConceroContract",
          //   account,
          //   args: [dstChainSelector, dstProxyContract],
          //   chain: viemChain,
          // });
          // const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);

          const setDstConceroContractHash = await walletClient.writeContract({
            address: conceroProxy,
            abi,
            functionName: "setConceroContract",
            account,
            args: [dstChainSelector, dstProxy],
            chain: viemChain,
          });

          const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
            ...viemReceiptConfig,
            hash: setDstConceroContractHash,
          });

          log(
            `[Set] ${conceroProxyAlias}.dstConceroContract[${dstName}] -> ${dstProxyAlias}. Gas: ${formatGas(setDstConceroContractGasUsed)}`,
            "setConceroProxyDstContracts",
            name,
          );
        }
      } catch (error) {
        err(`${error.message}`, "setConceroProxyDstContracts", name);
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
    const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, dcName);
    const { walletClient, publicClient, account } = getFallbackClients(deployableChain);
    const { signer: dcSigner } = getEthersV5FallbackSignerAndProvider(dcName);

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
      ...viemReceiptConfig,
      hash: setDstConceroContractHash,
    });

    log(
      `[Set] ${conceroProxyAlias}.donHostedSecretsVersion -> ${rowBySlotId.version}. Gas: ${formatGas(setDstConceroContractGasUsed)}`,
      "setDonHostedSecretsVersion",
      dcName,
    );
  } catch (error) {
    err(`${error.message}`, "setDonHostedSecretsVersion", dcName);
  }
}

async function setJsHashes(deployableChain: CNetwork, abi: any) {
  try {
    const { viemChain, name } = deployableChain;
    const { walletClient, publicClient, account } = getFallbackClients(deployableChain);
    const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, name);
    const conceroSrcCode = await (await fetch(infraSrcJsCodeUrl)).text();
    const conceroDstCode = await (await fetch(infraDstJsCodeUrl)).text();
    const ethersCode = await (await fetch(ethersV6CodeUrl)).text();

    const setHash = async (hash: string, functionName: string) => {
      const { request: setHashReq } = await publicClient.simulateContract({
        address: conceroProxy,
        abi,
        functionName,
        account,
        args: [hash],
        chain: viemChain,
      });
      const setHashHash = await walletClient.writeContract(setHashReq);
      const { cumulativeGasUsed: setHashGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setHashHash,
      });

      log(
        `[Set] ${conceroProxyAlias}.jshash -> ${shorten(hash)}. Gas: ${formatGas(setHashGasUsed)}`,
        "setJsHashes",
        name,
      );
    };

    await setHash(getHashSum(conceroDstCode), "setDstJsHashSum");
    await setHash(getHashSum(conceroSrcCode), "setSrcJsHashSum");
    await setHash(getHashSum(ethersCode), "setEthersHashSum");
  } catch (error) {
    err(`${error.message}`, "setHashSum", deployableChain.name);
  }
}

export async function setDstConceroPools(deployableChain: CNetwork, abi: any) {
  const { viemChain: dcViemChain, name: dcName } = deployableChain;
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);
  const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, dcName);
  const chainsToSet = deployableChain.type === networkTypes.mainnet ? mainnetChains : testnetChains;

  try {
    for (const chain of chainsToSet) {
      const { name: dstChainName, chainSelector: dstChainSelector } = chain;
      const [dstConceroPool, dstConceroPoolAlias] =
        chain === CNetworks.base || chain === CNetworks.baseSepolia
          ? getEnvAddress(ProxyType.parentPoolProxy, dstChainName)
          : getEnvAddress(ProxyType.childPoolProxy, dstChainName);
      const { request: setDstConceroPoolReq } = await publicClient.simulateContract({
        address: conceroProxy,
        abi,
        functionName: "setDstConceroPool",
        account,
        args: [dstChainSelector, dstConceroPool],
        chain: dcViemChain,
      });
      const setDstConceroPoolHash = await walletClient.writeContract(setDstConceroPoolReq);
      const { cumulativeGasUsed: setDstConceroPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setDstConceroPoolHash,
      });
      log(
        `[Set] ${conceroProxyAlias}.dstConceroPool[${dstChainName}] -> ${dstConceroPoolAlias}. Gas: ${formatGas(setDstConceroPoolGasUsed)}`,
        "setDstConceroPool",
        dcName,
      );
    }
  } catch (error) {
    err(`${error.message}`, "setDstConceroPool", dcName);
  }
}

export async function setDonSecretsSlotId(deployableChain: CNetwork, slotId: number, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);
  const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, dcName);

  try {
    const { request: setDonSecretsSlotIdReq } = await publicClient.simulateContract({
      address: conceroProxy,
      abi,
      functionName: "setDonHostedSecretsSlotID",
      account,
      args: [slotId],
      chain: dcViemChain,
    });
    const setDonSecretsSlotIdHash = await walletClient.writeContract(setDonSecretsSlotIdReq);
    const { cumulativeGasUsed: setDonSecretsSlotIdGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setDonSecretsSlotIdHash,
    });
    log(
      `[Set] ${conceroProxyAlias}.donSecretsSlotId -> ${slotId}. Gas: ${formatGas(setDonSecretsSlotIdGasUsed)}`,
      "setDonHostedSecretsSlotID",
      dcName,
    );
  } catch (error) {
    err(`${error.message}`, "setDonHostedSecretsSlotID", dcName);
  }
}

export async function setDexSwapAllowedRouters(deployableChain: CNetwork, abi: any) {
  const { viemChain: dcViemChain, name: dcName } = deployableChain;
  const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, dcName);
  const [allowedRouter, allowedRouterAlias] = getEnvAddress("uniswapRouter", dcName);
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);

  try {
    const { request: setDexRouterReq } = await publicClient.simulateContract({
      address: conceroProxy,
      abi,
      functionName: "setDexRouterAddress",
      account,
      args: [allowedRouter, 1n],
      chain: dcViemChain,
    });
    const setDexRouterHash = await walletClient.writeContract(setDexRouterReq);
    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setDexRouterHash,
    });
    log(
      `[Set] ${conceroProxyAlias}.dexRouterAddress -> ${allowedRouterAlias}. Gas: ${formatGas(setDexRouterGasUsed)}`,
      "setDexRouterAddress",
      dcName,
    );
  } catch (error) {
    err(`${error.message}`, "setDexRouterAddress", dcName);
  }
}

export async function setFunctionsPremiumFees(deployableChain: CNetwork, abi: any) {
  const defaultFee = 20000000000000000n;
  const fees: Record<CNetworkNames, bigint> = {
    polygon: 33131965864723535n,
    arbitrum: 20000000000000000n,
    base: 60000000000000000n,
    avalanche: 240000000000000000n,
  };

  const { viemChain: dcViemChain, name: dcName, type } = deployableChain;
  const [conceroProxy, conceroProxyAlias] = getEnvAddress(ProxyType.infraProxy, dcName);
  const { walletClient, publicClient, account } = getFallbackClients(deployableChain);

  const chainsToSet = type === networkTypes.mainnet ? mainnetChains : testnetChains;

  for (const chain of chainsToSet) {
    try {
      const feeToSet = fees[dcName] ?? defaultFee;
      const { request: setFunctionsPremiumFeesReq } = await publicClient.simulateContract({
        address: conceroProxy,
        abi,
        functionName: "setClfPremiumFees",
        account,
        args: [chain.chainSelector, feeToSet],
        chain: dcViemChain,
      });

      const setFunctionsPremiumFeesHash = await walletClient.writeContract(setFunctionsPremiumFeesReq);
      const { cumulativeGasUsed: setFunctionsPremiumFeesGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: setFunctionsPremiumFeesHash,
      });

      log(
        `[Set] ${conceroProxyAlias}.functionsPremiumFees[${dcName}] -> ${feeToSet}. Gas: ${formatGas(setFunctionsPremiumFeesGasUsed)}`,
        "setClfPremiumFees",
        dcName,
      );
    } catch (error) {
      err(`${error.message}`, "setClfPremiumFees", dcName);
    }
  }
}

export async function setContractVariables(deployableChains: CNetwork[], slotId: number, uploadsecrets: boolean) {
  const { abi } = await load("../artifacts/contracts/Orchestrator.sol/Orchestrator.json");

  for (const deployableChain of deployableChains) {
    if (deployableChain.type === networkTypes.mainnet) await setDexSwapAllowedRouters(deployableChain, abi); // once
    await setDstConceroPools(deployableChain, abi); // once

    await setDonHostedSecretsVersion(deployableChain, slotId, abi);
    await setDonSecretsSlotId(deployableChain, slotId, abi);

    await setFunctionsPremiumFees(deployableChain, abi);
    await setJsHashes(deployableChain, abi);
  }
}
