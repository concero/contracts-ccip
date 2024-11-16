import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import log from "../../../utils/log";
import { formatEther } from "viem";
import { getEthersV6FallbackSignerAndProvider } from "../../../utils/getEthersSignerAndProvider";
import { TransactionOptions } from "@chainlink/functions-toolkit";

const { SubscriptionManager } = require("@chainlink/functions-toolkit");

/* MAKE SURE TO accept ToS in the Functions UI if they haven't been accepted yet, otherwise will throw an error */
task("clf-sub-accept", "Accepts ownership of an Functions subscription after a transfer is requested")
  .addParam("subid", "Subscription ID")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { linkToken, functionsRouter, confirmations, name, url } = conceroNetworks[hre.network.name];
    const { signer } = getEthersV6FallbackSignerAndProvider(name);
    // const { signer: v6Signer, provider: v6Provider } = getEthersV6SignerAndProvider(url);
    // const { gasPrice } = await v6Provider.getFeeData();
    const subscriptionId = parseInt(taskArgs.subid);

    // tip: polygon might require custom gas price
    const txOptions: TransactionOptions = {
      confirmations,
      overrides: { gasLimit: 500000n },
    };

    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();

    const currentOwner = (await sm.getSubscriptionInfo(subscriptionId)).owner;
    log(
      `Accepting ownership of subscription ${subscriptionId} from current owner ${currentOwner}...`,
      "clf-sub-accept",
      name,
    );
    const acceptTx = await sm.acceptSubTransfer({ subscriptionId, txOptions });

    log(
      `Acceptance request completed in Tx: ${acceptTx.transactionHash}. \n${signer.address} is now the owner of subscription ${subscriptionId}.`,
      "clf-sub-accept",
      name,
    );

    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    // parse balances into LINK for readability
    subInfo.balance = formatEther(subInfo.balance) + " LINK";
    subInfo.blockedBalance = formatEther(subInfo.blockedBalance) + " LINK";
    log(`Updated Subscription Info: ${subInfo}`, "clf-sub-accept", name);
  });

export default {};
