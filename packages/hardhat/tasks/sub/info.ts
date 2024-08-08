import { task } from "hardhat/config";
import { SubscriptionManager } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import { formatEther } from "viem";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// run with: bunx hardhat clf-sub-info --subid 5810 --network avalancheFuji
task(
  "clf-sub-info",
  "Gets the Functions billing subscription balance, owner, and list of authorized consumer contract addresses",
)
  .addParam("subid", "Subscription ID")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");

    const { name, live } = hre.network;
    const subscriptionId = parseInt(taskArgs.subid);

    const signer = await hre.ethers.getSigner();
    const linkTokenAddress = chains[name].linkToken;
    const functionsRouterAddress = chains[name].functionsRouter;

    const sm = new SubscriptionManager({ signer, linkTokenAddress, functionsRouterAddress });
    await sm.initialize();

    const subInfo = await sm.getSubscriptionInfo(subscriptionId);
    subInfo.balance = formatEther(subInfo.balance) + " LINK";
    subInfo.blockedBalance = formatEther(subInfo.blockedBalance) + " LINK";
    console.log(`\nInfo for subscription ${subscriptionId}:\n`, subInfo);
  });

export default {};
