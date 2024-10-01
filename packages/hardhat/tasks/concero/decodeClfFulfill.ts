import { task } from "hardhat/config";
import cNetworks from "../../constants/cNetworks";
import { getFallbackClients } from "../../utils";
import { decodeAbiParameters, parseAbiParameters } from "viem";

// Define the types for decoding
const abiParameters = parseAbiParameters([
  "bytes32[3] reportContext",
  "bytes report",
  "bytes32[] rs",
  "bytes32[] ss",
  "bytes32 rawVs",
]);

const reportAbiParameters = parseAbiParameters([
  "bytes32[] requestIds",
  "bytes[] results",
  "bytes[] errors",
  "bytes[] onchainMetadata",
  "bytes[] offchainMetadata",
]);

task("decode-clf-fulfill", "Decodes CLF TX to get signers and fulfillment data")
  .addParam("txhash", "Transaction hash to decode")
  .setAction(async taskArgs => {
    const chain = cNetworks[hre.network.name];
    const { publicClient } = getFallbackClients(chain);
    const tx = await publicClient.getTransaction({
      hash: taskArgs.txhash,
    });

    // Remove '0x' prefix and the function selector (first 4 bytes)
    const inputData = tx.input.slice(10);

    const decodedData = decodeAbiParameters(abiParameters, `0x${inputData}`);
    const decodedReport = decodeAbiParameters(reportAbiParameters, decodedData[1]);

    const formattedData = {
      reportContext: decodedData[0],
      report: {
        requestIds: decodedReport[0],
        results: decodedReport[1],
        errors: decodedReport[2],
        onchainMetadata: decodedReport[3],
        offchainMetadata: decodedReport[4],
      },
      rs: decodedData[2],
      ss: decodedData[3],
      rawVs: decodedData[4],
    };

    console.log(JSON.stringify(formattedData, null, 2));
    return formattedData;
  });

export default {};
