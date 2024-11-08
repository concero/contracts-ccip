import { task } from "hardhat/config";
import { decodeEventLog, encodeEventTopics, getAbiItem, Hash } from "viem";
import { cNetworks } from "../../../constants";
import { CNetwork } from "../../../types/CNetwork";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getChainBySelector, getEnvAddress, getFallbackClients } from "../../../utils";
import { findEventLog } from "./findCLFRequestProcessedLog";
import functionsRouterAbi from "@chainlink/contracts/abi/v0.8/FunctionsRouter.json";
import functionsCoordinatorAbi from "@chainlink/contracts/abi/v0.8/FunctionsCoordinator.json";
import { getDecodedEventByTxReceipt } from "./getDecodedEventByTxReceipt";
import { abi as conceroBridgeAbi } from "../../../artifacts/contracts/ConceroBridge.sol/ConceroBridge.json";
import { DecodeEventLogReturnType } from "viem/utils/abi/decodeEventLog";
import { getCLFFeesTaken } from "./getCLFFeesTaken";
import { displayResults } from "./displayResults";
import { fetchPriceFeeds } from "./fetchPriceFeeds";
/*
Todos:
1. Find src CLF callback to get CLF LINK final cost on src
2. Use dsttx to get gas paid by messenger EOA for addUnconfirmedTx
3. Find dst CLF callback to get CLF LINK final cost and gas used on dst
*/

const oracleRequestEventABI = getAbiItem({ abi: functionsCoordinatorAbi, name: "OracleRequest" });
const unconfirmedTXSentEventABI = getAbiItem({ abi: conceroBridgeAbi, name: "UnconfirmedTXSent" });
const requestProcessedEventAbi = getAbiItem({ abi: functionsRouterAbi, name: "RequestProcessed" });
const unconfirmedTXAddedEventAbi = getAbiItem({ abi: conceroBridgeAbi, name: "UnconfirmedTXAdded" });

export async function getSwapAndBridgeCost(srctx: Hash, dsttx: Hash, srcChain: CNetwork) {
  const { publicClient: srcPublicClient } = getFallbackClients(srcChain);
  const srcTx = await srcPublicClient.getTransaction({ hash: srctx });
  const srcTxReceipt = await srcPublicClient.getTransactionReceipt({ hash: srctx });

  // STEP 1: Get the total cost of the SRC CLF Callback in LINK
  const oracleRequestEvent = await getDecodedEventByTxReceipt(srcTxReceipt, [oracleRequestEventABI], "OracleRequest");

  const srcInfraProxy = getEnvAddress("infraProxy", srcChain.name)[0];
  const unconfirmedTXSentEvent = await getDecodedEventByTxReceipt(
    srcTxReceipt,
    [unconfirmedTXSentEventABI],
    "UnconfirmedTXSent",
    srcInfraProxy,
  );
  const { ccipMessageId: conceroMessageId, dstChainSelector } = unconfirmedTXSentEvent.args;

  const dstChain = getChainBySelector(String(dstChainSelector));
  const dstInfraProxy = getEnvAddress("infraProxy", dstChain.name)[0];
  const { publicClient: dstPublicClient } = getFallbackClients(dstChain);

  const clfRequestProcessedEvent = await findEventLog(
    "RequestProcessed",
    { requestId: oracleRequestEvent.args.requestId },
    functionsRouterAbi,
    srcTx.blockNumber,
    srcTx.blockNumber + BigInt(100),
    srcChain.functionsRouter,
    srcPublicClient,
  );
  const { totalCostJuels: srcClfFeePaid } = clfRequestProcessedEvent.args;
  // console.log(`Total Cost of SRC CLF: ${totalCostJuels.toString()}`);

  // STEP 2: Get the total cost of the DST CLF Callback in LINK
  const dstTx = await dstPublicClient.getTransaction({ hash: dsttx });
  const dstTxReceipt = await dstPublicClient.getTransactionReceipt({ hash: dsttx });

  const { args: dstRequestProcessedArgs } = await getDecodedEventByTxReceipt(
    dstTxReceipt,
    [requestProcessedEventAbi],
    "RequestProcessed",
  );

  // console.log(`Total cost of DST CLF: ${dstRequestProcessedArgs.totalCostJuels.toString()}`);

  // STEP 3: Get the gas paid by the messenger EOA for the UnconfirmedTXAdded tx
  const dstTopics = encodeEventTopics({
    abi: [unconfirmedTXAddedEventAbi],
    eventName: "UnconfirmedTXAdded",
    args: { ccipMessageId: conceroMessageId },
  });

  const dstLogs = await dstPublicClient.getLogs({
    fromBlock: dstTx.blockNumber - BigInt(100),
    toBlock: dstTx.blockNumber,
    address: dstInfraProxy,
    topics: dstTopics,
  });

  let dstUnconfirmedTXAddedEvent: DecodeEventLogReturnType;
  let dstUnconfirmedTXLog;
  for (const log of dstLogs) {
    try {
      // console.log(log);
      const event = decodeEventLog({
        abi: [unconfirmedTXAddedEventAbi],
        data: log.data,
        topics: log.topics,
      });

      if (event.args.ccipMessageId.toString() === conceroMessageId.toString()) {
        dstUnconfirmedTXAddedEvent = event;
        dstUnconfirmedTXLog = log;
      }
    } catch (err) {}
  }

  const dstUnconfirmedTx = await dstPublicClient.getTransaction({
    hash: dstUnconfirmedTXLog.transactionHash,
  });
  const dstUnconfirmedTxReceipt = await dstPublicClient.getTransactionReceipt({
    hash: dstUnconfirmedTXLog.transactionHash,
  });
  const dstGasPaid = dstUnconfirmedTx.gasPrice * dstUnconfirmedTxReceipt.gasUsed;

  // Step 4: get CLFFees in contracts
  const { srcClfFeeTaken, dstClfFeeTaken, srcMessengerGasFeeTaken, dstMessengerGasFeeTaken } = await getCLFFeesTaken(
    srcPublicClient,
    srcInfraProxy,
    srcChain.chainSelector,
    dstChainSelector,
    srcTx.blockNumber,
  );

  // Step 5: Get LINKUSD and USDCUSD price feeds by block number
  const { LINKUSDPrice, USDCUSDPrice } = await fetchPriceFeeds(srcChain, srcPublicClient, srcTx.blockNumber);
  const convertLinkToUSDC = linkAmount => {
    const linkInUSD = BigInt(linkAmount) * BigInt(LINKUSDPrice);
    return linkInUSD / BigInt(USDCUSDPrice);
  };

  displayResults({
    srcClfFeeTaken,
    dstClfFeeTaken,
    srcClfFeePaid: convertLinkToUSDC(srcClfFeePaid),
    dstClfFeePaid: convertLinkToUSDC(dstRequestProcessedArgs.totalCostJuels),
    srcMessengerGasFeeTaken,
    dstMessengerGasFeeTaken,
    dstGasPaid,
  });
}

task("get-swap-and-bridge-cost")
  .addParam("srctx", "The source chain transaction hash")
  .addParam("dsttx", "The destination chain transaction hash")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { srctx, dsttx } = taskArgs;
    const srcChain = cNetworks[hre.network.name];
    await getSwapAndBridgeCost(srctx, dsttx, srcChain);
  });
