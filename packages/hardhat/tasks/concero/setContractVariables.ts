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

export async function setContractVariables(liveChains: CNetwork[], deployableChains: CNetwork[], slotId: number) {
  const { abi } = await load("../artifacts/contracts/Concero.sol/Concero.json");
  for (const chain of liveChains) {
    const { viemChain, url, name } = chain;
    try {
      const contract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);
      const { walletClient, publicClient, account } = getClients(viemChain, url);

      // set dstChain contracts for each contract
      for (const dstChain of liveChains) {
        const { name: dstName, chainSelector: dstChainSelector } = dstChain;
        if (dstName !== name) {
          const dstContract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[dstName]}`);
          const { request: setDstConceroContractReq } = await publicClient.simulateContract({
            address: contract,
            abi,
            functionName: "setConceroContract",
            account,
            args: [dstChainSelector, dstContract],
            chain: viemChain,
          });
          const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
          const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
            hash: setDstConceroContractHash,
          });
          log(
            `Set ${name}:${contract} dstConceroContract[${dstName}, ${dstContract}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
            "setContractVariables",
          );
        }
      }
    } catch (error) {
      log(`Error for ${name}: ${error.message}`, "setContractVariables");
    }
  }

  for (const deployableChain of deployableChains) {
    await setDonHostedSecretsVersion(deployableChain, slotId, abi);
    await addMessengerToAllowlist(deployableChain, abi);
    await setConceroPool(deployableChain, abi, liveChains);
    await setJsHashes(deployableChain, abi, liveChains);
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
    const dcContract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[dcName]}`);
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);

    // // fetch slotId from contract
    // const slotIdHash = await publicClient.readContract({
    //   address: dcContract,
    //   abi,
    //   functionName: "slotId",
    //   account,
    //   chain: dcViemChain,
    // });
    const { signer: dcSigner } = getEthersSignerAndProvider(dcUrl);

    // set DONSecrets version
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
      address: dcContract,
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
      `Set ${dcName}:${dcContract} donHostedSecretsVersion[${rowBySlotId.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
      "setContractVariables",
    );
  } catch (error) {
    log(`Error for ${dcName}: ${error.message}`, "setContractVariables");
  }
}

async function addMessengerToAllowlist(deployableChain: CNetwork, abi: any) {
  const { url: dcUrl, viemChain: dcViemChain, name: dcName } = deployableChain;
  const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
  try {
    const dcContract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[dcName]}`);

    const messengerWallet = getEnvVar("MESSENGER_ADDRESS");
    const { request: addToAllowlistReq } = await publicClient.simulateContract({
      address: dcContract,
      abi,
      functionName: "setConceroMessenger",
      account,
      args: [messengerWallet],
      chain: dcViemChain,
    });
    const addToAllowlistHash = await walletClient.writeContract(addToAllowlistReq);
    const { cumulativeGasUsed: addToAllowlistGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: addToAllowlistHash,
    });
    log(
      `Set ${dcName}:${dcContract} allowlist[${messengerWallet}]. Gas used: ${addToAllowlistGasUsed.toString()}`,
      "setContractVariables",
    );
  } catch (error) {
    if (error.message.includes("Address already in allowlist")) {
      log(`${messengerWallet} was already added to allowlist of ${dcContract}`, "setContractVariables");
    } else {
      log(`Error for ${dcName}: ${error.message}`, "setContractVariables");
    }
  }
}

async function setConceroPool(deployableChain: CNetwork, abi: any, liveChains: CNetwork[]) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = deployableChain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const srcConceroPoolAddress = getEnvVar(`CONCEROCCIP_${networkEnvKeys[srcChainName]}`);

    for (const dstChain of liveChains) {
      const { name: dstChainName, chainSelector: dstChainSelector } = dstChain;
      const dstConceroPoolAddress = getEnvVar(`CONCEROPOOL_${networkEnvKeys[dstChainName]}`);

      if (!dstChainSelector) {
        log(`No chainSelector found for ${dstChainName}`, "setContractVariables");
        continue;
      }

      const { request: setPoolReq } = await publicClient.simulateContract({
        address: srcConceroPoolAddress as Address,
        abi,
        functionName: "setConceroPool",
        account,
        args: [dstChainSelector, dstConceroPoolAddress],
        chain: dcViemChain,
      });
      const setPoolHash = await walletClient.writeContract(setPoolReq);
      const { cumulativeGasUsed: setPoolGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: setPoolHash,
      });
      log(
        `Set ${dstChainName}:${dstConceroPoolAddress} pool[${dstConceroPoolAddress}]. Gas used: ${setPoolGasUsed.toString()}`,
        "setContractVariables",
      );
    }
  } catch (error) {
    log(`Error ${error.message}`, "setContractVariables");
  }
}

async function setJsHashes(deployableChain: CNetwork, abi: any, liveChains: CNetwork[]) {
  try {
    const { url: dcUrl, viemChain: dcViemChain, name: srcChainName } = deployableChain;
    const { walletClient, publicClient, account } = getClients(dcViemChain, dcUrl);
    const conceroContractAddress = getEnvVar(`CONCEROCCIP_${networkEnvKeys[srcChainName]}`);
    const conceroDstCode = await (
      await fetch(
        "https://raw.githubusercontent.com/concero/contracts-ccip/release/packages/hardhat/tasks/CLFScripts/dist/DST.min.js",
      )
    ).text();
    const conceroSrcCode = await (
      await fetch(
        "https://raw.githubusercontent.com/concero/contracts-ccip/release/packages/hardhat/tasks/CLFScripts/dist/SRC.min.js",
      )
    ).text();
    const ethersCode = await (
      await fetch("https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js")
    ).text();

    const setHash = async (hash, functionName) => {
      const { request: setHashReq } = await publicClient.simulateContract({
        address: conceroContractAddress as Address,
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
        `Set ${srcChainName}:${conceroContractAddress} jshash[${hash}]. Gas used: ${setHashGasUsed.toString()}`,
        "setContractVariables",
      );
    };

    await setHash(getHashSum(conceroDstCode), "setDstJsHashSum");
    await setHash(getHashSum(conceroSrcCode), "setSrcJsHashSum");
    await setHash(getHashSum(ethersCode), "setEthersHashSum");
  } catch (error) {
    log(`Error ${error.message}`, "setContractVariables");
  }
}

//todo: add set hash
