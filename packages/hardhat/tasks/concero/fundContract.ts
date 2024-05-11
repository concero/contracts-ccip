import { CNetwork } from "../../types/CNetwork";
import ierc20Abi from "@chainlink/contracts/abi/v0.8/IERC20.json";
import { getClients } from "../utils/switchChain";
import { networkEnvKeys } from "../../constants/CNetworks";
import { dripBnm } from "./dripBnm";
import { task } from "hardhat/config";
import { liveChains } from "./deployInfra";
import chains from "../../constants/CNetworks";

export async function ensureDeployerBnMBalance(chains: CNetwork[]) {
  //checks balance of CCIPBnm of deployer
  for (const chain of chains) {
    const { ccipBnmToken, viemChain, url, name } = chain;
    const { publicClient, account } = getClients(viemChain, url);
    const balance = await publicClient.readContract({
      address: ccipBnmToken,
      abi: ierc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    });

    if (balance < 5n * 10n ** 18n) {
      console.log(`Deployer ${name}:${account.address} has insufficient CCIPBNM balance. Dripping...`);
      await dripBnm([chain], 5);
    }
  }
}
export async function fundContract(chains: CNetwork[], amount: number = 1) {
  for (const chain of chains) {
    const { name, viemChain, ccipBnmToken, url } = chain;
    const contract = process.env[`CONCEROCCIP_${networkEnvKeys[name]}`];
    const { walletClient, publicClient, account } = getClients(viemChain, url);
    const gasPrice = await publicClient.getGasPrice();
    await ensureDeployerBnMBalance(chains);
    const { request: sendReq } = await publicClient.simulateContract({
      functionName: "transfer",
      abi: ierc20Abi,
      account,
      address: ccipBnmToken,
      args: [contract, BigInt(amount) * 10n ** 18n],
      gasPrice,
    });
    const sendHash = await walletClient.writeContract(sendReq);
    const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({ hash: sendHash });
    console.log(`Sent ${amount} CCIPBNM to ${name}:${contract}. Gas used: ${sendGasUsed.toString()}`);
  }
}

task("fund-contracts", "Funds the contract with CCIPBNM tokens")
  .addOptionalParam("amount", "Amount of CCIPBNM to send", "5")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    const amount = parseInt(taskArgs.amount, 10);
    if (name !== "localhost" && name !== "hardhat") {
      await fundContract([chains[name]], amount);
    } else {
      for (const chain of liveChains) {
        await fundContract([chain], amount);
      }
    }
  });

export default {};
