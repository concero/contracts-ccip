import { getSecretsBySlotId } from "../utils/getSecretsBySlotId";
import load from "../../../utils/load";
import { getClients } from "../../utils/switchChain";
import { getEnvVar } from "../../../utils/getEnvVar";
import CNetworks, { networkEnvKeys } from "../../../constants/CNetworks";
import log from "../../../utils/log";
import { Address } from "viem";
import getHashSum from "../../../utils/getHashSum";
import { automationsJsCodeUrl, ethersV6CodeUrl } from "../../../constants/functionsJsCodeUrls";

const setDonHostedSecretsVersion = async (hre, slotId: number, abi) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const secretsVersion = (await getSecretsBySlotId(hre.network.name, slotId)).version;
    const { walletClient, publicClient, account } = getClients(chain.viemChain, chain.url);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`) as Address;

    const { request: setDstConceroContractReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setDonHostedSecretsVersion",
      account,
      args: [secretsVersion],
      chain: viemChain,
    });
    const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
    log(`setDonHostedSecretsVersion tx: ${setDstConceroContractHash}`, "setDonHostedSecretsVersion");
  } catch (error) {
    log(`Error for ${hre.network.name}: ${error.message}`, "setDonHostedSecretsVersion");
  }
};

const setForwarderAddress = async (hre, forwarderAddress: string, abi: any) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getClients(chain.viemChain, chain.url);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`) as Address;

    const { request: setForwarderAddressReq } = await publicClient.simulateContract({
      address: automationsContract,
      abi,
      functionName: "setForwarderAddress",
      account,
      args: [forwarderAddress],
      chain: viemChain,
    });

    const setForwarderAddressHash = await walletClient.writeContract(setForwarderAddressReq);
    log(`setForwarderAddress tx: ${setForwarderAddressHash}`, "setForwarderAddress");
  } catch (error) {
    log(`Error for ${name}: ${error.message}`, "setForwarderAddress");
  }
};

const setHashSum = async (hre, abi: any) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getClients(chain.viemChain, chain.url);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`) as Address;
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
    log(`setHashSum tx: ${setHashSumHash}`, "setJsHashSum");
  } catch (error) {
    log(`Error for ${hre.network.name}: ${error.message}`, "setJsHashSum");
  }
};

const setEthersHashSum = async (hre, abi: any) => {
  try {
    const chain = CNetworks[hre.network.name];
    const { viemChain } = chain;
    const { walletClient, publicClient, account } = getClients(viemChain, chain.url);
    const automationsContract = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`) as Address;
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
    log(`setEthersHashSum tx: ${setEthersHashSumHash}`, "setEthersHashSum");
  } catch (error) {
    log(`Error for ${hre.network.name}: ${error.message}`, "setEthersHashSum");
  }
};

export async function setAutomationsVariables(hre, slotId: number, forwarderAddress: string) {
  const { abi } = await load("../artifacts/contracts/ConceroAutomation.sol/ConceroAutomation.json");

  await setDonHostedSecretsVersion(hre, slotId, abi);
  await setForwarderAddress(hre, forwarderAddress, abi);
  await setHashSum(hre, abi);
  await setEthersHashSum(hre, abi);
}
