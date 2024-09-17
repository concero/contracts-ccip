import { CNetwork } from "../../types/CNetwork";
import ierc20Abi from "@chainlink/contracts/abi/v0.8/IERC20.json";
import chains, { networkEnvKeys } from "../../constants/cNetworks";
import { dripBnm } from "./dripBnm";
import { task } from "hardhat/config";
import { liveChains } from "./deployInfra/deployInfra";
import { getEnvVar } from "../../utils";
import log, { err } from "../../utils/log";
import { viemReceiptConfig } from "../../constants";

export async function ensureDeployerBnMBalance(chains: CNetwork[]) {
  //checks balance of CCIPBnm of deployer
  for (const chain of chains) {
    const { ccipBnmToken, viemChain, url, name } = chain;
    const { publicClient, account } = getFallbackClients(chain);
    const balance = await publicClient.readContract({
      address: ccipBnmToken,
      abi: ierc20Abi,
      functionName: "balanceOf",
      args: [account.address],
    });

    if (balance < 5n * 10n ** 18n) {
      log(
        `Deployer ${name}:${account.address} has insufficient CCIPBNM balance. Dripping...`,
        "ensureDeployerBnMBalance",
      );
      await dripBnm([chain], 5);
    }
  }
}

export async function fundContract(chains: CNetwork[], amount: number = 1) {
  for (const chain of chains) {
    const { name, viemChain, ccipBnmToken, url } = chain;
    try {
      const contract = getEnvVar(`CONCERO_BRIDGE_${networkEnvKeys[name]}`);
      const { walletClient, publicClient, account } = getFallbackClients(chain);
      await ensureDeployerBnMBalance(chains);
      const { request: sendReq } = await publicClient.simulateContract({
        functionName: "transfer",
        abi: ierc20Abi,
        account,
        address: ccipBnmToken,
        args: [contract, BigInt(amount) * 10n ** 18n],
      });
      const sendHash = await walletClient.writeContract(sendReq);
      const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: sendHash,
      });
      log(`Sent ${amount} CCIPBNM to ${name}:${contract}. Gas used: ${sendGasUsed.toString()}`, "fundContract");
    } catch (error) {
      err(`${error.message}`, "fundContract", name);
    }
  }
}

task("fund-contracts", "Funds the contract with CCIPBNM tokens")
  .addOptionalParam("amount", "Amount of CCIPBNM to send", "5")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    const amount = parseInt(taskArgs.amount, 10);
    if (live) {
      await fundContract([chains[name]], amount);
    } else {
      for (const chain of liveChains) {
        await fundContract([chain], amount);
      }
    }
  });

export default {};
