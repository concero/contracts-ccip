import { task } from "hardhat/config";
import { SubscriptionManager } from "@chainlink/functions-toolkit";
import networks from "../../constants/CLFnetworks";

// run with: bunx hardhat functions-sub-fund --amount 0.01 --subid 5810 --network avalancheFuji
const subIds = [
  process.env.CLF_SUBID_SEPOLIA,
  process.env.CLF_SUBID_ARBITRUM_SEPOLIA,
  process.env.CLF_SUBID_OPTIMISM_SEPOLIA,
  process.env.CLF_SUBID_FUJI,
  process.env.CLF_SUBID_BASE_SEPOLIA,
];

task("functions-sub-fund", "Funds a billing subscription for Functions consumer contracts")
  .addParam("amount", "Amount to fund subscription in LINK")
  .addParam("subid", "Subscription ID to fund")
  .setAction(async taskArgs => {
    if (!subIds.includes(taskArgs.subid)) throw new Error("Sub ID not present in known sub ids");

    const signer = await ethers.getSigner();
    const linkTokenAddress = networks[network.name]["linkToken"];
    const functionsRouterAddress = networks[network.name]["functionsRouter"];
    const txOptions = { confirmations: networks[network.name].confirmations };

    const subscriptionId = parseInt(taskArgs.subid);
    const linkAmount = taskArgs.amount;
    const juelsAmount = ethers.utils.parseUnits(linkAmount, 18).toString();

    const sm = new SubscriptionManager({ signer, linkTokenAddress, functionsRouterAddress });
    await sm.initialize();
    //
    // await utils.prompt(
    //   `\nPlease confirm that you wish to fund Subscription ${subscriptionId} with ${chalk.blue(
    //     linkAmount + " LINK"
    //   )} from your wallet.`
    // )

    console.log(`\nFunding subscription ${subscriptionId} with ${linkAmount} LINK...`);

    const fundTxReceipt = await sm.fundSubscription({ juelsAmount, subscriptionId, txOptions });
    console.log(`\nSubscription ${subscriptionId} funded with ${linkAmount} LINK in Tx: ${fundTxReceipt.transactionHash}`);

    const subInfo = await sm.getSubscriptionInfo(subscriptionId);

    // parse balances into LINK for readability
    subInfo.balance = hre.ethers.formatEther(subInfo.balance) + " LINK";
    subInfo.blockedBalance = hre.ethers.formatEther(subInfo.blockedBalance) + " LINK";

    console.log("\nUpdated subscription Info: ", subInfo);
  });
export default {};
