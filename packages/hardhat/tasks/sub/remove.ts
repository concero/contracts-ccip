import chains from "../../constants/CNetworks";
import { formatEther } from "viem";
import { task } from "hardhat/config";
import { SubscriptionManager } from "@chainlink/functions-toolkit";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Overrides } from "ethers-v5";

task("clf-sub-consumer-rm", "Removes a consumer contract from an Functions billing subscription")
  .addOptionalParam("subid", "Subscription ID", undefined)
  .addParam("contract", "Address(es) of the consumer contract to remove from billing subscription")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);

    const signer = await hre.ethers.getSigner();
    const { linkToken, functionsRouter, confirmations } = chains[name];
    const consumerAddresses = taskArgs.contract.split(",");
    for (const consumerAddress of consumerAddresses) {
      let subscriptionId;
      if (!taskArgs.subid) {
        console.log(`No subscription ID provided, defaulting to ${chains[name].functionsSubIds[0]}`);
        subscriptionId = chains[name].functionsSubIds[0];
      } else subscriptionId = parseInt(taskArgs.subId);

      const txOptions = { confirmations, overrides: { gasLimit: 10000000 } };
      const sm = new SubscriptionManager({
        signer,
        linkTokenAddress: linkToken,
        functionsRouterAddress: functionsRouter,
      });
      await sm.initialize();

      console.log(`\nRemoving ${consumerAddress} from subscription ${subscriptionId}...`);

      let removeConsumerTx = await sm.removeConsumer({ subscriptionId, consumerAddress, txOptions });
      const subInfo = await sm.getSubscriptionInfo(subscriptionId);
      // parse balances into LINK for readability using formatEther from @viem/core
      subInfo.balance = formatEther(subInfo.balance) + " LINK";
      subInfo.blockedBalance = formatEther(subInfo.blockedBalance) + " LINK";
      console.log(
        `\nRemoved ${consumerAddress} from subscription ${subscriptionId} in Tx: ${removeConsumerTx.transactionHash}\nUpdated Subscription Info:\n`,
        subInfo,
      );
    }
  });

export default {};
