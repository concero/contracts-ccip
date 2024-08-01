import { task, types } from "hardhat/config";
import { fetchRequestCommitment, SubscriptionManager, TransactionOptions } from "@chainlink/functions-toolkit";
import chains from "../../constants/CNetworks";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getEthersSignerAndProvider } from "../utils/getEthersSignerAndProvider";
import { Overrides } from "ethers";

task("clf-sub-timeout", "Times out expired Functions requests which have not been fulfilled within 5 minutes")
  .addParam("requestids", "1 or more request IDs to timeout separated by commas")
  .addOptionalParam("toblock", "Ending search block number (defaults to latest block)")
  .addOptionalParam("pastblockstosearch", "Number of past blocks to search", 1000, types.int)
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name, live } = hre.network;
    if (!chains[name]) throw new Error(`Chain ${name} not supported`);

    const requestIdsToTimeout = taskArgs.requestids.split(",");
    console.log(`Timing out requests ${requestIdsToTimeout} on ${name}`);
    const toBlock = taskArgs.toblock ? Number(taskArgs.toblock) : "latest";
    const pastBlocksToSearch = parseInt(taskArgs.pastblockstosearch);
    const { signer, provider } = getEthersSignerAndProvider(chains[name].url);
    const { linkToken, functionsRouter, functionsDonIdAlias, confirmations } = chains[name];
    const txOptions: TransactionOptions = { confirmations, overrides: { gasLimit: 500000n } };

    const sm = new SubscriptionManager({
      signer,
      linkTokenAddress: linkToken,
      functionsRouterAddress: functionsRouter,
    });
    await sm.initialize();

    const requestCommitments = [];
    for (const requestId of requestIdsToTimeout) {
      try {
        const requestCommitment = await fetchRequestCommitment({
          requestId,
          provider,
          functionsRouterAddress: functionsRouter,
          donId: functionsDonIdAlias,
          toBlock,
          pastBlocksToSearch,
        });
        console.log(`Fetched commitment for request ID ${requestId}`);
        if (requestCommitment.timeoutTimestamp < BigInt(Math.round(Date.now() / 1000))) {
          requestCommitments.push(requestCommitment);
        } else {
          console.log(`Request ID ${requestId} has not expired yet (skipping)`);
        }
      } catch (error) {
        console.log(`Failed to fetch commitment for request ID ${requestId} (skipping): ${error}`);
      }
    }

    if (requestCommitments.length > 0) {
      await sm.timeoutRequests({ requestCommitments });
    }
  });

export default {};
