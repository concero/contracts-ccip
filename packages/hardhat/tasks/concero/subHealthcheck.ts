import { networkEnvKeys } from "../../constants/CNetworks";
import { formatUnits, getContract } from "viem";
import functionsRouterAbi from "@chainlink/contracts/abi/v0.8/FunctionsRouter.json";
import linkTokenAbi from "@chainlink/contracts/abi/v0.8/LinkToken.json";
import { getClients } from "../utils/switchChain";
import { encodeAbiParameters } from "viem";
import { CNetwork } from "../../types/CNetwork";
import { getEnvVar } from "../../utils/getEnvVar";

export async function subHealthcheck(selectedChains: CNetwork[]) {
  for (const chain of selectedChains) {
    const { linkToken, functionsRouter, functionsSubIds, viemChain, url, name } = chain;
    const { walletClient, publicClient } = getClients(viemChain, url);
    const contract = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);
    // console.log(`Checking subscription for ${contract} on ${name}`);

    const functionsRouterContract = getContract({
      address: functionsRouter,
      abi: functionsRouterAbi,
      client: { public: publicClient, wallet: walletClient },
    });
    const { balance, consumers } = await functionsRouterContract.read.getSubscription([functionsSubIds[0]]);
    const minBalance = 250n * 10n ** 18n; // Set minimum balance to 250 LINK

    if (balance < minBalance) {
      const amountToFund = minBalance - balance;
      // console.log(`Funding Sub ${functionsSubIds[0]} on ${networkName} with ${formatUnits(amountToFund, 18)} LINK`);
      const linkTokenContract = getContract({
        address: linkToken,
        abi: linkTokenAbi,
        client: { public: publicClient, wallet: walletClient },
      });
      const encodedData = encodeAbiParameters([{ type: "uint64", name: "subscriptionId" }], [functionsSubIds[0]]);

      const hash = await linkTokenContract.write.transferAndCall([functionsRouter, amountToFund, encodedData]);
      const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
      console.log(
        `Funded Sub ${functionsSubIds[0]} with ${formatUnits(amountToFund, 18)} LINK. Tx Hash: ${hash} Gas used: ${cumulativeGasUsed.toString()}`,
      );
    }

    if (!consumers.map(c => c.toLowerCase()).includes(contract.toLowerCase())) {
      // console.log(`Adding consumer ${contract} to Sub ${functionsSubIds[0]}`);
      const hash = await functionsRouterContract.write.addConsumer([functionsSubIds[0], contract.toLowerCase()]);
      const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
      console.log(
        `Consumer ${name}:${contract} added to Sub ${functionsSubIds[0]}. Tx Hash: ${hash} Gas used: ${cumulativeGasUsed.toString()}`,
      );
    } else {
      console.log(`Consumer ${name}:${contract} is already subscribed to ${functionsSubIds[0]}. Skipping...`);
    }
  }
}
