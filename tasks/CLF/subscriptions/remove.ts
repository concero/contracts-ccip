import { conceroNetworks, networkEnvKeys } from "../../../constants/conceroNetworks";
import { task, types } from "hardhat/config";
import { SubscriptionManager, TransactionOptions } from "@chainlink/functions-toolkit";
import { getEnvVar, getFallbackClients, log } from "../../../utils";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../../types/CNetwork";
import chainlinkFunctionsRouterAbi from "@chainlink/contracts/abi/v0.8/FunctionsRouter.json";
import { privateKeyToAccount } from "viem/accounts";
import { viemReceiptConfig } from "../../../constants";

task("clf-sub-consumer-rm", "Removes consumer contracts from a Functions billing subscription")
  .addOptionalParam("subid", "Subscription ID", undefined, types.int)
  .addOptionalParam("contract", "Address(es) of the consumer contract to remove or keep")
  .addOptionalParam("keepcontracts", "If specified, removes all except this address", undefined, types.string)
  .setAction(async ({ subid, contract, keepcontracts }, hre) => {
    const signer = await hre.ethers.getSigner();
    const chain = conceroNetworks[hre.network.name];
    const { functionsSubIds, linkToken, functionsRouter, confirmations } = chain;
    const subscriptionId = subid || functionsSubIds[0];
    const txOptions: TransactionOptions = { confirmations, overrides: { gasLimit: 1000000n } };

    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();

    if (keepcontracts) {
      await handleSelectiveRemoval(hre, chain, sm, subscriptionId, keepcontracts);
    } else {
      await handleDirectRemoval(sm, chain, subscriptionId, contract.split(","));
    }
  });

async function handleSelectiveRemoval(
  hre: HardhatRuntimeEnvironment,
  chain: CNetwork,
  sm,
  subscriptionId,
  keepcontracts: string,
) {
  const subInfo = await sm.getSubscriptionInfo(subscriptionId);
  const consumersToKeep = keepcontracts.split(",").map(consumer => consumer.toLowerCase());
  const consumersToRemove = subInfo.consumers.filter(consumer => !consumersToKeep.includes(consumer.toLowerCase()));

  console.log(`Removing consumers: ${consumersToRemove.join(", ")}, keeping: ${keepcontracts}`);

  for (const consumerAddress of consumersToRemove) {
    await removeConsumer(chain, subscriptionId, consumerAddress);
  }
}

async function handleDirectRemoval(sm, chain: CNetwork, subscriptionId, consumerAddresses) {
  for (const consumerAddress of consumerAddresses) {
    await removeConsumer(chain, subscriptionId, consumerAddress);
  }
}

async function removeConsumer(chain: CNetwork, subscriptionId: number, consumerAddress: string) {
  try {
    const { publicClient, walletClient } = getFallbackClients(chain);
    const clfRouterAddress = getEnvVar(`CLF_ROUTER_${networkEnvKeys[chain.name]}`);
    const account = privateKeyToAccount("0x" + getEnvVar(`DEPLOYER_PRIVATE_KEY`));
    console.log(`Removing ${consumerAddress} from subscription ${subscriptionId}...`);

    // const gasPrice = await publicClient.getGasPrice();

    // const maxFeePerGas = gasPrice * 3n;
    // const maxPriorityFeePerGas = hre.ethers.utils.parseUnits("2", "wei"); // Set a priority fee
    const { request } = await publicClient.simulateContract({
      chain: chain.viemChain,
      account,
      to: clfRouterAddress,
      abi: chainlinkFunctionsRouterAbi,
      functionName: "removeConsumer",
      args: [BigInt(subscriptionId), consumerAddress],
    });

    const transactionHash = await walletClient.writeContract(request);
    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({
      hash: transactionHash,
      ...viemReceiptConfig,
    });

    log(
      `Removed ${consumerAddress} from subId ${subscriptionId}. Tx: ${transactionHash}. Gas: ${cumulativeGasUsed}`,
      "clf-sub-consumer-rm",
    );
  } catch (error) {
    console.error(`Failed to remove ${consumerAddress} from subscription ${subscriptionId}: ${error}`);
  }
}

export default {};
