import { networkEnvKeys } from "../constants/CNetworks";
import { abi } from "../artifacts/contracts/Concero.sol/Concero.json"; //todo: this can be old if changed during execution.
import { CNetwork } from "../types/CNetwork";
import { getClients } from "./switchChain";

export async function setContractVariables(selectedChains: CNetwork[]) {
  for (const chain of selectedChains) {
    const { viemChain, url, name } = chain;
    const contract = process.env[`CONCEROCCIP_${networkEnvKeys[name]}`]; // grabbing up-to-date var
    const { walletClient, publicClient, account } = getClients(viemChain, url);

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
        const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({ hash: setDstConceroContractHash });
        console.log(`Set ${name}:${contract} dstConceroContract[${dstName}, ${dstContract}]. Gas used: ${setDstConceroContractGasUsed.toString()}`);
      }
    }

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
      const { cumulativeGasUsed: addToAllowlistGasUsed } = await publicClient.waitForTransactionReceipt({ hash: addToAllowlistHash });
      console.log(`Added ${process.env.MESSENGER_WALLET_ADDRESS} to allowlist. Gas used: ${addToAllowlistGasUsed.toString()}`);
    } catch (e) {
      console.log(`Failed to add ${process.env.MESSENGER_WALLET_ADDRESS} to allowlist: ${e}`);
    }
  }
}
