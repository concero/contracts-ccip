import { SubscriptionManager } from "@chainlink/functions-toolkit";
import networks from "../../constants/CLFnetworks";

// run with: bunx hardhat functions-sub-add --subid 5811 --contract 0x... --network avalancheFuji
task("functions-sub-add", "Adds a consumer contract to the Functions billing subscription")
  .addParam("subid", "Subscription ID")
  .addParam("contract", "Address of the Functions consumer contract to authorize for billing")
  .setAction(async taskArgs => {
    const consumerAddress = taskArgs.contract;
    const subscriptionId = parseInt(taskArgs.subid);
    const signer = await hre.ethers.getSigner(process.env.WALLET_ADDRESS);

    const linkTokenAddress = networks[network.name]["linkToken"];
    const functionsRouterAddress = networks[network.name]["functionsRouter"];
    const txOptions = { confirmations: networks[network.name].confirmations };

    const sm = new SubscriptionManager({ signer, linkTokenAddress, functionsRouterAddress });
    await sm.initialize();

    console.log(`\nAdding ${consumerAddress} to subscription ${subscriptionId}...`);
    const addConsumerTx = await sm.addConsumer({ subscriptionId, consumerAddress, txOptions });
    console.log(`Added consumer contract ${consumerAddress} in Tx: ${addConsumerTx.transactionHash}`);
  });
export default {};
