import { task } from "hardhat/config";
import { SubscriptionManager } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import { formatEther } from "viem";

// run with: bunx hardhat functions-sub-info --subid 5810 --network avalancheFuji
task("functions-sub-info", "Gets the Functions billing subscription balance, owner, and list of authorized consumer contract addresses")
  .addParam("subid", "Subscription ID")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);

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
