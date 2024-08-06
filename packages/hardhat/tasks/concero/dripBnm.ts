import { CNetwork } from "../../types/CNetwork";
import chains from "../../constants/CNetworks";
import { liveChains } from "./deployInfra/deployInfra";
import { task } from "hardhat/config";
import { viemReceiptConfig } from "../../constants/deploymentVariables";

export async function dripBnm(chains: CNetwork[], amount: number = 20) {
  for (const chain of chains) {
    const { ccipBnmToken, viemChain, url, name } = chain;
    const { walletClient, publicClient, account } = getFallbackClients(chain);
    const gasPrice = await publicClient.getGasPrice();

    for (let i = 0; i < amount; i++) {
      const { request: sendReq } = await publicClient.simulateContract({
        functionName: "drip",
        abi: [
          {
            inputs: [{ internalType: "address", name: "to", type: "address" }],
            name: "drip",
            outputs: [],
            stateMutability: "nonpayable",
            type: "function",
          },
        ],
        account,
        address: ccipBnmToken,
        args: [account.address],
        gasPrice,
      });

      const sendHash = await walletClient.writeContract(sendReq);
      const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({
        ...viemReceiptConfig,
        hash: sendHash,
      });
      console.log(`Sent 1 CCIPBNM token to ${name}:${account.address}. Gas used: ${sendGasUsed.toString()}`);
    }
  }
}

task("drip-bnm", "Drips CCIPBNM tokens to the deployer")
  .addOptionalParam("amount", "Amount of CCIPBNM to drip", "5")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    const amount = parseInt(taskArgs.amount, 10);
    if (name !== "localhost" && name !== "hardhat") {
      await dripBnm([chains[name]], amount);
    } else {
      for (const chain of liveChains) {
        await dripBnm([chain], amount);
      }
    }
  });

export default {};
