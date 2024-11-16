import log, { getEnvVar, getFallbackClients } from "../../utils";
import { task } from "hardhat/config";
import conceroNetworks, { networkEnvKeys } from "../../constants/conceroNetworks";

export async function callContractFunction() {
  const chain = conceroNetworks.base;

  const { walletClient, publicClient, account } = getFallbackClients(chain);
  const gasPrice = await publicClient.getGasPrice();

  const parentPoolProxy = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[chain.name]}`);
  const { request: sendReq } = await publicClient.simulateContract({
    functionName: "clearDepositsOnTheWay",
    abi: [
      {
        inputs: [],
        stateMutability: "nonpayable",
        type: "function",
        name: "clearDepositsOnTheWay",
        outputs: [],
      },
    ],
    account,
    address: parentPoolProxy,
    args: [],
    gasPrice,
  });

  const sendHash = await walletClient.writeContract(sendReq);
  const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({
    hash: sendHash,
  });
  log(
    `Deleted deposit on the way with from ${parentPoolProxy}. Tx: ${sendHash} Gas used: ${sendGasUsed}`,
    "callContractFunction",
    chain.name,
  );
}

task("call-contract-function", "Calls a specific contract function. Use for testing and maintenance").setAction(
  async (taskArgs, hre) => {
    await callContractFunction();
  },
);

export default {};
