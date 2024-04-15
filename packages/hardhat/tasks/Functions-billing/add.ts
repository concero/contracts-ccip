import { SubscriptionManager } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import { task } from "hardhat/config";

// run with: bunx hardhat functions-sub-add --subid 5810 --contract 0x... --network avalancheFuji
task("functions-sub-add", "Adds a consumer contract to the Functions billing subscription")
  .addParam("subid", "Subscription ID")
  .addParam("contract", "Address of the Functions consumer contract to authorize for billing")
  .setAction(async taskArgs => {
    const { name } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);
    const consumerAddress = taskArgs.contract;
    const subscriptionId = parseInt(taskArgs.subid);
    const signer = await hre.ethers.getSigner(process.env.WALLET_ADDRESS);
    const { linkToken, functionsRouter, confirmations } = chains[name];
    const txOptions = { confirmations };

    const sm = new SubscriptionManager({ signer, linkTokenAddress: linkToken, functionsRouterAddress: functionsRouter });
    await sm.initialize();

    console.log(`\nAdding ${consumerAddress} to subscription ${subscriptionId}...`);
    const addConsumerTx = await sm.addConsumer({ subscriptionId, consumerAddress, txOptions });
    console.log(`Added consumer contract ${consumerAddress} in Tx: ${addConsumerTx.transactionHash}`);
  });
export default {};
