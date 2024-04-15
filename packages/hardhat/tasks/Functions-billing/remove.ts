import chains from "../../constants/CNetworks";
import { formatEther } from "viem";
import { task } from "hardhat/config";
import { SubscriptionManager } from "@chainlink/functions-toolkit";

task("functions-sub-remove", "Removes a consumer contract from an Functions billing subscription")
  .addParam("subid", "Subscription ID")
  .addParam("contract", "Address of the consumer contract to remove from billing subscription")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);

    const signer = await hre.ethers.getSigner();
    const { linkToken, functionsRouter, confirmations } = chains[name];
    const consumerAddress = taskArgs.contract;
    const subscriptionId = parseInt(taskArgs.subid);
    const txOptions = { confirmations };

    const sm = new SubscriptionManager({ signer, linkTokenAddress: linkToken, functionsRouterAddress: functionsRouter });
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
  });
export default {};
