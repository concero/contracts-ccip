import { getSecretsBySlotId } from "./getSecretsBySlotId";
import load from "../../../utils/load";
import { getFallbackClients } from "../../../utils/getViemClients";
import { getEnvVar } from "../../../utils/getEnvVar";
import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import log, { err } from "../../../utils/log";
import getHashSum from "../../../utils/getHashSum";
import { automationsJsCodeUrl, ethersV6CodeUrl } from "../../../constants/functionsJsCodeUrls";
import { viemReceiptConfig } from "../../../constants/deploymentVariables";

const setDonHostedSecretsVersion = async (hre, slotId: number, abi) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const secretsVersion = (await getSecretsBySlotId(hre.network.name, slotId)).version;

    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`);

    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setDonHostedSecretsVersion",
      account,
      args: [secretsVersion],
      chain: viemChain,
    });
    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);

    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setDstConceroContractHash,
    });

    log(`setDonHostedSecretsVersion tx: ${setDstConceroContractHash}`, "setDonHostedSecretsVersion");
  } catch (error) {
    err(`${error.message}`, "setDonHostedSecretsVersion", hre.network.name);
  }
};

const setDonHostedSecretsSlotId = async (hre, slotId: number, abi: any) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`);

    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setDonHostedSecretsSlotId",
      account,
      args: [slotId],
      chain: viemChain,
    });

    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);

    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setDstConceroContractHash,
    });

    log(`setDonHostedSecretsSlotId tx: ${setDstConceroContractHash}`, "setDonHostedSecretsSlotId");
  } catch (error) {
    err(`${error.message}`, "setDonHostedSecretsSlotId", hre.network.name);
  }
};

const setForwarderAddress = async (hre, forwarderAddress: string, abi: any) => {
  const name = hre.network.name;
  try {
    const chain = CNetworks[name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`);

    const { request: setForwarderAddressReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setForwarderAddress",
      account,
      args: [forwarderAddress],
      chain: viemChain,
    });

    const setForwarderAddressHash = await walletClient.writeContract(setForwarderAddressReq);

    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setForwarderAddressHash,
    });

    log(`setForwarderAddress tx: ${setForwarderAddressHash}`, "setForwarderAddress");
  } catch (error) {
    err(`${error.message}`, "setForwarderAddress", name);
  }
};

const setHashSum = async (hre, abi: any) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`);
    const jsCodeHashSum = getHashSum(await (await fetch(automationsJsCodeUrl)).text());

    const { request: setHashSumReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setJsHashSum",
      account,
      args: [jsCodeHashSum],
      chain: viemChain,
    });

    const setHashSumHash = await walletClient.writeContract(setHashSumReq);

    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setHashSumHash,
    });

    log(`setHashSum tx: ${setHashSumHash}`, "setJsHashSum");
  } catch (error) {
    err(`${error.message}`, "setJsHashSum", hre.network.name);
  }
};

const setEthersHashSum = async (hre, abi: any) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`);
    const jsCodeHashSum = getHashSum(await (await fetch(ethersV6CodeUrl)).text());

    const { request: setEthersHashSumReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setEthersHashSum",
      account,
      args: [jsCodeHashSum],
      chain: viemChain,
    });

    const setEthersHashSumHash = await walletClient.writeContract(setEthersHashSumReq);

    const { cumulativeGasUsed: setDexRouterGasUsed } = await publicClient.waitForTransactionReceipt({
      ...viemReceiptConfig,
      hash: setEthersHashSumHash,
    });

    log(`setEthersHashSum tx: ${setEthersHashSumHash}`, "setEthersHashSum");
  } catch (error) {
    err(`${error.message}`, "setEthersHashSum", hre.network.name);
  }
};

export async function setAutomationsVariables(hre, slotId: number, forwarderAddress: string | undefined) {
  const { abi } = await load("../artifacts/contracts/ConceroAutomation.sol/ConceroAutomation.json");

  await setDonHostedSecretsVersion(hre, slotId, abi);
  await setDonHostedSecretsSlotId(hre, slotId, abi);
  await setHashSum(hre, abi);
  await setEthersHashSum(hre, abi);

  if (forwarderAddress) {
    await setForwarderAddress(hre, forwarderAddress, abi);
  }
}
