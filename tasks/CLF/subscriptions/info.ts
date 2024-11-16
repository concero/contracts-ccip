import { task } from "hardhat/config";
import { SubscriptionManager } from "@chainlink/functions-toolkit";
import { conceroNetworks } from "../../../constants/conceroNetworks";
import { formatEther } from "viem";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getEthersV5FallbackSignerAndProvider } from "../../../utils/getEthersSignerAndProvider";

task(
  "clf-sub-info",
  "Gets the Functions billing subscription balance, owner, and list of authorized consumer contract addresses",
)
  .addOptionalParam("subid", "Subscription ID", undefined)
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");

    const { name, live } = hre.network;
    const { linkToken, functionsRouter, functionsSubIds } = conceroNetworks[name];

    const subscriptionId = taskArgs.subid ? parseInt(taskArgs.subid) : functionsSubIds[0];

    const { signer } = await getEthersV5FallbackSignerAndProvider(name);
    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();
    console.log(`Getting info for subscription ${subscriptionId}...`);

    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    subInfo.blockedBalance = formatEther(subInfo.blockedBalance) + " LINK";
    console.log(BigInt(subInfo.balance));
    console.log(`\nInfo for subscription ${subscriptionId}:\n`, subInfo);
  });

export default {};
