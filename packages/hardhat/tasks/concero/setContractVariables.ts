import { networkEnvKeys } from "../../constants/CNetworks";
import { CNetwork } from "../../types/CNetwork";
import { getClients } from "../utils/switchChain";
import load from "../../utils/load";
import { getEnvVar } from "../../utils/getEnvVar";
import log from "../../utils/log";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import { SecretsManager } from "@chainlink/functions-toolkit";

export async function setContractVariables(selectedChains: CNetwork[], slotId: number) {
  const { abi } = await load("../artifacts/contracts/Concero.sol/Concero.json");
  for (const chain of selectedChains) {
    const { viemChain, url, name, functionsGatewayUrls, functionsRouter, functionsDonIdAlias } = chain;
    const contract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);
    const { signer } = getEthersSignerAndProvider(url);

    const { walletClient, publicClient, account } = getClients(viemChain, url);

    // set dstChain contracts for each contract
    for (const dstChain of selectedChains) {
      const { name: dstName, chainSelector: dstChainSelector } = dstChain;
      if (dstName !== name) {
        const dstContract = process.env[`CONCEROCCIP_${networkEnvKeys[dstName]}`];
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

    // Add Messenger to allowlist
    try {
      const { request: addToAllowlistReq } = await publicClient.simulateContract({
        address: contract,
        abi,
        functionName: "setConceroMessenger",
        account,
        args: [process.env.MESSENGER_WALLET_ADDRESS],
        chain: viemChain,
      });
      const addToAllowlistHash = await walletClient.writeContract(addToAllowlistReq);
      const { cumulativeGasUsed: addToAllowlistGasUsed } = await publicClient.waitForTransactionReceipt({
        hash: addToAllowlistHash,
      });
      log(
        `Set ${name}:${contract} allowlist[${process.env.MESSENGER_WALLET_ADDRESS}]. Gas used: ${addToAllowlistGasUsed.toString()}`,
        "setContractVariables",
      );
    } catch (error) {
      if (error.message.includes("Address already in allowlist")) {
        log(
          `${process.env.MESSENGER_WALLET_ADDRESS} was already added to allowlist of ${contract}`,
          "setContractVariables",
        );
      }
    }

    // set DONSecrets version
    const secretsManager = new SecretsManager({
      signer,
      functionsRouterAddress: functionsRouter,
      donId: functionsDonIdAlias,
    });
    await secretsManager.initialize();

    const { result } = await secretsManager.listDONHostedEncryptedSecrets(functionsGatewayUrls);
    const nodeResponse = result.nodeResponses[0];
    if (!nodeResponse.rows) return log(`No secrets found for ${name}.`, "updateContract");
    const rowBySlotId = nodeResponse.rows.find(row => row.slot_id === slotId);
    if (!rowBySlotId) return log(`No secrets found for ${name} at slot ${slotId}.`, "updateContract");
    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
      address: contract,
      abi,
      functionName: "setDonHostedSecretsVersion",
      account,
      args: [rowBySlotId.version],
      chain: viemChain,
    });
    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
    const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: setDstConceroContractHash,
    });
    log(
      `Set ${name}:${contract} donHostedSecretsVersion[${name}, ${rowBySlotId.version}]. Gas used: ${setDstConceroContractGasUsed.toString()}`,
      "setContractVariables",
    );
  }
}
