import { task } from "hardhat/config";
import cNetworks from "../../constants/cNetworks";
import { getEnvVar, getFallbackClients } from "../../utils";
import { decodeAbiParameters, parseAbiParameters } from "viem";
import { ethers } from "ethers-v5";
import { CNetwork } from "../../types/CNetwork";

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

// Authorized node operator addresses
const authorizedSigners = [
  getEnvVar("CLF_DON_SIGNING_KEY_0_BASE"),
  getEnvVar("CLF_DON_SIGNING_KEY_1_BASE"),
  getEnvVar("CLF_DON_SIGNING_KEY_2_BASE"),
  getEnvVar("CLF_DON_SIGNING_KEY_3_BASE"),
];

/**
 * Decodes the Chainlink Functions report from a transaction hash.
 * @param {string} hash - The transaction hash to decode.
 * @param {CNetwork} chain - The chain network configuration.
 * @returns {Promise<object>} - The formatted report data.
 */
async function decodeReport(hash: string, chain: CNetwork) {
  const { publicClient } = getFallbackClients(chain);
  const tx = await publicClient.getTransaction({ hash });

  // Remove '0x' prefix and the function selector (first 4 bytes)
  const inputData = tx.input.slice(10);

  // Decode the transaction input data
  const decodedData = decodeAbiParameters(abiParameters, `0x${inputData}`);

  // Extract and decode the report
  const reportBytes = decodedData[1];
  const decodedReport = decodeAbiParameters(reportAbiParameters, reportBytes);

  // Format the decoded data
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
    reportBytes: reportBytes,
  };

  console.log("Decoded Report:", JSON.stringify(formattedData, null, 2));

  return formattedData;
}

/**
 * Verifies the report signatures against the authorized signers.
 * @param {object} formattedData - The formatted report data from decodeReport.
 * @throws Will throw an error if verification fails.
 */
function verifyReport(formattedData) {
  const { reportContext, reportBytes, rs, ss, rawVs } = formattedData;

  // Step 1: Recompute 'h'
  const reportHash = ethers.utils.keccak256(reportBytes);
  const messageToHash = ethers.utils.concat([
    ethers.utils.arrayify(reportHash),
    ethers.utils.arrayify(reportContext[0]),
    ethers.utils.arrayify(reportContext[1]),
    ethers.utils.arrayify(reportContext[2]),
  ]);
  const h = ethers.utils.keccak256(messageToHash);
  console.log(`Recomputed 'h': ${h}`);

  // Step 2: Recover and verify signers
  const rawVsBytes = ethers.utils.arrayify(rawVs);
  const uniqueSigners = new Set();

  for (let i = 0; i < rs.length; i++) {
    const r = rs[i];
    const s = ss[i];
    const rawVsByte = rawVsBytes[i];
    const v = rawVsByte + 27; // Convert rawVs to v (27 or 28)

    const signature = {
      r: r,
      s: s,
      v: v,
    };

    // Recover the signer's address from the signature
    const signerAddress = ethers.utils.recoverAddress(h, signature);

    // Check for duplicate signatures
    if (uniqueSigners.has(signerAddress)) {
      throw new Error("Duplicate signature detected");
    }

    uniqueSigners.add(signerAddress);

    // Verify if the signer is authorized
    if (!authorizedSigners.includes(signerAddress)) {
      throw new Error(`Unauthorized signer: ${signerAddress}`);
    }
  }

  console.log("All signatures are valid and from authorized signers.");
}

task("decode-clf-fulfill", "Decodes CLF TX to get signers and fulfillment data")
  .addParam("txhash", "Transaction hash to decode")
  .setAction(async (taskArgs, hre) => {
    const chain = cNetworks[hre.network.name];

    const formattedData = await decodeReport(taskArgs.txhash, chain);
    verifyReport(formattedData);
  });

export default {};
