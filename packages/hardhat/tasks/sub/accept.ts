import hre from "hardhat";

const { SubscriptionManager } = require("@chainlink/functions-toolkit");
import { task } from "hardhat/config";
import chains from "../../constants/CNetworks";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import log from "../../utils/log";
import { formatEther } from "viem";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import { TransactionOptions } from "@chainlink/functions-toolkit";

task("clf-sub-accept", "Accepts ownership of an Functions subscription after a transfer is requested")
  .addParam("subid", "Subscription ID")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { linkToken, functionsRouter, confirmations, name, url } = chains[hre.network.name];
    const { signer } = await getEthersSignerAndProvider(url);

    const subscriptionId = parseInt(taskArgs.subid);
    const txOptions: TransactionOptions = { confirmations, overrides: { gasLimit: 500000n } };

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
    );
    const acceptTx = await sm.acceptSubTransfer({ subscriptionId, txOptions });

    log(
      `Acceptance request completed in Tx: ${acceptTx.transactionHash}. \n${signer.address} is now the owner of subscription ${subscriptionId}.`,
      "clf-sub-accept",
    );

    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    // parse balances into LINK for readability
    subInfo.balance = formatEther(subInfo.balance) + " LINK";
    subInfo.blockedBalance = formatEther(subInfo.blockedBalance) + " LINK";
    log(`Updated Subscription Info: ${subInfo}`, "clf-sub-accept");
  });

export default {};
