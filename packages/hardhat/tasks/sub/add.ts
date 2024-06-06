import { SubscriptionManager } from "@chainlink/functions-toolkit";
import chains, { networkEnvKeys } from "../../constants/CNetworks";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../types/CNetwork";

import log from "../../utils/log";
import { Address } from "viem";

// run with: bunx hardhat clf-consumer-add --subid 5810 --contract 0x... --network avalancheFuji
task("clf-sub-consumer-add", "Adds a consumer contract to the Functions billing subscription")
  .addOptionalParam("subid", "Subscription ID", undefined)
  .addParam("contract", "Address(es) of the Functions consumer contract to authorize for billing")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);
    const consumerAddress = taskArgs.contract;
    let subscriptionId;
    if (!taskArgs.subid) {
      console.log(`No subscription ID provided, defaulting to ${chains[name].functionsSubIds[0]}`);
      subscriptionId = chains[name].functionsSubIds[0];
    } else subscriptionId = parseInt(taskArgs.subId);

    const consumerAddresses = taskArgs.contract.split(",");
    await addCLFConsumer(chains[name], consumerAddresses, subscriptionId);
  });

async function addCLFConsumer(chain: CNetwork, consumerAddresses: Address[], subscriptionId: number) {
  const { linkToken, functionsRouter, confirmations, name, url } = chain;
  const signer = await hre.ethers.getSigner(process.env.DEPLOYER_ADDRESS);
  for (const consumerAddress of consumerAddresses) {
    const txOptions = { confirmations };
    log(`Adding ${consumerAddress} to sub ${subscriptionId} on ${name}`, "addCLFConsumer");

    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();

    try {
      const addConsumerTx = await sm.addConsumer({ subscriptionId, consumerAddress, txOptions });
      log(`Successfully added ${consumerAddress} to sub ${subscriptionId} on ${name}.`, "addCLFConsumer");
    } catch (error) {
      if (error.message.includes("is already authorized to use subscription")) log(error.message, "deployConcero");
      else console.error(error);
    }
  }
}

export default addCLFConsumer;
