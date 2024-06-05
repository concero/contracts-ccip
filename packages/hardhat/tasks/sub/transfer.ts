import { task } from "hardhat/config";
import { SubscriptionManager, TransactionOptions } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import log from "../../utils/log";

task("clf-sub-transfer", "Request ownership of an Functions subscription be transferred to a new address")
  .addParam("subid", "Subscription ID")
  .addParam("newowner", "Address of the new owner")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");

    const { name } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);

    const subscriptionId = parseInt(taskArgs.subid);
    const newOwner = taskArgs.newowner;
    const { linkToken, functionsRouter, confirmations } = chains[name];
    const txOptions: TransactionOptions = { confirmations, overrides: { gasLimit: 500000n } };

    const signer = await hre.ethers.getSigner(process.env.DEPLOYER_ADDRESS);

    // await utils.prompt(
    //   `\nTransferring the subscription to a new owner will require generating a new signature for encrypted secrets. ` +
    //     `Any previous encrypted secrets will no longer work with subscription ID ${subscriptionId} and must be regenerated by the new owner.`,
    // );

    // return console.log({ signer, linkToken, functionsRouter, confirmations, subscriptionId, newOwner, txOptions });
    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();

    console.log(`\nRequesting transfer of subscription ${subscriptionId} to new owner ${newOwner}`);

    const requestTransferTx = await sm.requestSubscriptionTransfer({ subscriptionId, newOwner, txOptions });

    console.log(
      `Transfer request completed in Tx: ${requestTransferTx.transactionHash}\nAccount ${newOwner} needs to accept transfer for it to complete.`,
    );
  });
export default {};
