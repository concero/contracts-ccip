import { task } from "hardhat/config";
import { decodeEventLog, encodeEventTopics, formatEther, getAbiItem, Hash } from "viem";
import { CNetwork } from "../../../types/CNetwork";
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
import fs from "fs";
import { getChainById } from "../../../utils/getChainBySelector";
import { analyseTxOutputFile } from "./analyseTxOutputFile";
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
  const [srcTx, srcTxReceipt] = await Promise.all([
    srcPublicClient.getTransaction({ hash: srctx }),
    srcPublicClient.getTransactionReceipt({ hash: srctx }),
  ]);
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

  const [dstUnconfirmedTx, dstUnconfirmedTxReceipt] = await Promise.all([
    dstPublicClient.getTransaction({
      hash: dstUnconfirmedTXLog.transactionHash,
    }),
    dstPublicClient.getTransactionReceipt({
      hash: dstUnconfirmedTXLog.transactionHash,
    }),
  ]);
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

  const srcClfFeePaidUSDC = convertLinkToUSDC(srcClfFeePaid);
  const dstClfFeePaidUSDC = convertLinkToUSDC(dstRequestProcessedArgs.totalCostJuels);
  const srcClfFeeDifference = BigInt(srcClfFeeTaken) - BigInt(srcClfFeePaidUSDC);
  const dstClfFeeDifference = BigInt(dstClfFeeTaken) - BigInt(dstClfFeePaidUSDC);
  const totalClfFeeDifference = srcClfFeeDifference + dstClfFeeDifference;

  const totalFeeDifference = totalClfFeeDifference; // adding msgr gas paid later
  displayResults({
    srcClfFeeTaken,
    dstClfFeeTaken,
    srcClfFeePaid: srcClfFeePaidUSDC,
    dstClfFeePaid: dstClfFeePaidUSDC,
    srcMessengerGasFeeTaken,
    dstMessengerGasFeeTaken,
    dstGasPaid,
  });
  console.log(`Total CLF Fee Difference: ${formatEther(totalFeeDifference)}`);

  return {
    srcClfFeeTaken,
    dstClfFeeTaken,
    srcClfFeePaid: srcClfFeePaidUSDC,
    dstClfFeePaid: dstClfFeePaidUSDC,
    srcMessengerGasFeeTaken,
    dstMessengerGasFeeTaken,
    dstGasPaid,
    totalFeeDifference,
  };
}

function appendToJSONFile(filePath, entry) {
  const fileData = JSON.parse(fs.readFileSync(filePath, "utf-8"));
  fileData.push(entry);

  fs.writeFileSync(
    filePath,
    JSON.stringify(fileData, (key, value) => (typeof value === "bigint" ? value.toString() : value), 2),
    "utf-8",
  );
}

task("get-swap-and-bridge-cost")
  .addOptionalParam("srctx", "The source chain transaction hash")
  .addOptionalParam("dsttx", "The destination chain transaction hash")
  .addOptionalParam("txsfilepath", "The path to the file containing the transaction hashes")
  .addOptionalParam("outputfilepath", "The path to the output file")
  .addOptionalParam("analysetxoutputfile", "The path to the file containing the processed tx output")
  .setAction(async taskArgs => {
    const { txsfilepath, outputfilepath, analysetxoutputfile } = taskArgs;

    if (analysetxoutputfile) {
      analyseTxOutputFile(analysetxoutputfile);
      return;
    }
    const errorFilePath = outputfilepath.replace(".json", "_errors.json");

    const txData = JSON.parse(fs.readFileSync(txsfilepath, "utf-8"));
    if (!fs.existsSync(outputfilepath)) {
      fs.writeFileSync(outputfilepath, JSON.stringify([]), "utf-8");
    }
    if (!fs.existsSync(errorFilePath)) {
      fs.writeFileSync(errorFilePath, JSON.stringify([]), "utf-8");
    }
    const outputData = [];

    for (const entity of txData) {
      const srcTxHash = entity.from?.txHash;
      const dstTxHash = entity.to?.txHash;
      const srcChain = getChainById(entity.from?.chainId);

      if (srcTxHash && dstTxHash && srcChain) {
        try {
          console.log(`Processing srcTxHash: ${srcTxHash}, dstTxHash: ${dstTxHash}`);
          const result = await getSwapAndBridgeCost(srcTxHash, dstTxHash, srcChain);
          const successEntry = {
            srcTxHash,
            dstTxHash,
            srcChainName: srcChain.name,
            ...result,
          };
          appendToJSONFile(outputfilepath, successEntry);
        } catch (err) {
          console.error(`Error processing tx ${srcTxHash} -> ${dstTxHash}:`, err);
          const errorEntry = {
            srcTxHash,
            dstTxHash,
            error: err.message || "Unknown error",
          };
          appendToJSONFile(errorFilePath, errorEntry); // Log error to separate file
        }
      }
    }
  });
