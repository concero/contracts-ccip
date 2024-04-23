import { CNetwork } from "../types/CNetwork";
import ierc20Abi from "@chainlink/contracts/abi/v0.8/IERC20.json";
import { formatUnits } from "viem";
import { getClients } from "./switchChain";
import { networkEnvKeys } from "../constants/CNetworks";
import { dripCCIPBnM } from "./dripCCIPBnM";

export async function ensureDeployerBnMBalance(chains: CNetwork[]) {
  //checks balance of CCIPBnm of deployer
  for (const chain of chains) {
    const { ccipBnmToken, viemChain, url, name } = chain;
    const { walletClient, publicClient, account } = getClients(viemChain, url);
    const balance = await publicClient.readContract({
      address: ccipBnmToken,
      abi: ierc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    });

    if (balance < 5n * 10n ** 18n) {
      console.log(`Deployer ${name}:${account.address} has insufficient CCIPBNM balance. Dripping...`);
      await dripCCIPBnM([chain], 5);
    }
  }
}
export async function fundContract(chains: CNetwork[]) {
  for (const chain of chains) {
    const { name, viemChain, ccipBnmToken, url } = chain;
    const contract = process.env[`CONCEROCCIP_${networkEnvKeys[name]}`];
    const { walletClient, publicClient, account } = getClients(viemChain, url);
    await ensureDeployerBnMBalance(chains);
    const { request: sendReq } = await publicClient.simulateContract({
      functionName: "transfer",
      abi: ierc20Abi,
      account,
      address: ccipBnmToken,
      args: [contract, 1n * 10n ** 18n],
    });
    const sendHash = await walletClient.writeContract(sendReq);
    const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({ hash: sendHash });
    console.log(`Sent 1 CCIPBNM token to ${name}:${contract}. Gas used: ${sendGasUsed.toString()}`);
  }
}
