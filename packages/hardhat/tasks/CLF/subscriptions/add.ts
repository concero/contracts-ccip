import { SubscriptionManager } from "@chainlink/functions-toolkit";
import { conceroNetworks } from "../../../constants/conceroNetworks";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../../types/CNetwork";
import log, { err, warn } from "../../../utils/log";
import { Address } from "viem";
import { shorten } from "../../../utils/formatting";
import { getEthersSignerAndProvider } from "../../../utils";

task("clf-sub-consumer-add", "Adds a consumer contract to the Functions billing subscription")
  .addOptionalParam("subid", "Subscription ID", undefined)
  .addParam("contract", "Address(es) of the Functions consumer contract to authorize for billing")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name, live } = hre.network;
    if (!conceroNetworks[name]) throw new Error(`Chain ${name} not supported`);
    let subscriptionId;
    if (!taskArgs.subid) {
      warn(
        `No subscription ID provided, defaulting to ${conceroNetworks[name].functionsSubIds[0]}`,
        "addCLFConsumer",
        name,
      );
      subscriptionId = conceroNetworks[name].functionsSubIds[0];
    } else subscriptionId = parseInt(taskArgs.subId);

    const consumerAddresses = taskArgs.contract.split(",");
    await addCLFConsumer(conceroNetworks[name], consumerAddresses, subscriptionId);
  });

async function addCLFConsumer(chain: CNetwork, consumerAddresses: Address[], subscriptionId: number) {
  const { linkToken, functionsRouter, confirmations, name } = chain;

  if (!chain.name) {
    throw new Error(`Chain ${chain.name} not found`);
  }

  const { signer } = getEthersSignerAndProvider(chain.url);

  for (const consumerAddress of consumerAddresses) {
    const txOptions = { confirmations };
    log(`Adding ${shorten(consumerAddress)} to sub ${subscriptionId}`, "addCLFConsumer", name);
    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });

    await sm.initialize();

    try {
      const addConsumerTx = await sm.addConsumer({ subscriptionId, consumerAddress, txOptions });

      log(`Successfully added ${consumerAddress} to sub ${subscriptionId} on ${name}.`, "addCLFConsumer", name);
    } catch (error) {
      if (error.message.includes("is already authorized to use subscription")) {
        err(error.message, "addCLFConsumer", name);
      } else {
        console.error(error);
      }
    }
  }
}

export default addCLFConsumer;
