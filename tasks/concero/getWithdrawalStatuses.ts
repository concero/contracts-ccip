import { task } from "hardhat/config";
import { getClients, getEnvVar } from "../../utils";
import log from "../../utils/log";
import { conceroNetworks, networkEnvKeys } from "../../constants/conceroNetworks";
import fs from "fs";
import { parseAbi } from "viem";

export async function getWithdrawalStatuses() {
  const chain = conceroNetworks.base;
  const { publicClient } = getClients(chain.name, chain.url);
  const contractAddress = getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[chain.name]}`);
  const { abi: parentPoolCLAAbi } = await import(
    "../../artifacts/contracts/ParentPoolCLFCLA.sol/ParentPoolCLFCLA.json"
  );

  // Get all withdrawal request IDs
  const withdrawalRequestIds = await publicClient.readContract({
    address: contractAddress,
    abi: parseAbi(["function getPendingRequests() external view returns (bytes32[] memory _requests)"]),
    functionName: "getPendingRequests",
    chain: chain.viemChain,
  });

  console.log(withdrawalRequestIds);
  //
  // Get the withdrawal triggered status for each ID
  const withdrawalStatuses = await Promise.all(
    withdrawalRequestIds.map(async id => {
      const isTriggered = await publicClient.readContract({
        address: contractAddress,
        abi: parentPoolCLAAbi,
        functionName: "s_withdrawTriggered",
        args: [id],
      });
      return { id, isTriggered };
    }),
  );

  console.log(withdrawalStatuses);

  return withdrawalStatuses;
}

task("get-withdrawal-statuses", "Reads and logs withdrawal request statuses").setAction(async (taskArgs, hre) => {
  try {
    const withdrawalStatuses = await getWithdrawalStatuses();

    // Convert to JSON
    const jsonData = JSON.stringify(withdrawalStatuses, null, 2);

    // Log to console
    console.log("Withdrawal Statuses:");
    console.log(jsonData);

    // Save to file
    fs.writeFileSync("withdrawal-statuses.json", jsonData);
    log("Withdrawal statuses saved to withdrawal-statuses.json", "get-withdrawal-statuses", "base");
  } catch (error) {
    log(`Error: ${error.message}`, "get-withdrawal-statuses", "base", "error");
  }
});
