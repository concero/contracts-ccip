import { task } from "hardhat/config";
import fs from "fs";
import secrets from "../constants/CLFSecrets";
import CLFSimulationConfig from "../constants/CLFSimulationConfig";

const { simulateScript, decodeResult } = require("@chainlink/functions-toolkit");
const path = require("path");
const process = require("process");

async function simulate(pathToFile, args) {
  if (!fs.existsSync(pathToFile)) return console.error(`File not found: ${pathToFile}`);
  console.log("Simulating script:", pathToFile);
  const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript({
    source: fs.readFileSync(pathToFile, "utf8"),
    args,
    secrets,
    ...CLFSimulationConfig,
  });
  if (errorString) {
    console.log("CAPTURED ERROR:");
    console.log(errorString);
  }

  if (capturedTerminalOutput) {
    console.log("CAPTURED TERMINAL OUTPUT:");
    console.log(capturedTerminalOutput);
  }

  if (responseBytesHexstring) {
    console.log("RESPONSE BYTES HEXSTRING:");
    console.log(responseBytesHexstring);
    console.log("RESPONSE BYTES DECODED:");
    console.log(decodeResult(responseBytesHexstring, "string"));
  }
}

/* run with: bunx hardhat functions-simulate-script */
task("functions-simulate-script", "Executes the JavaScript source code locally")
  // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../Functions-request-config.js`, types.string)
  .setAction(async (taskArgs, hre) => {
    console.log((await hre.ethers.getSigner()).address);
    await simulate(path.join(__dirname, "./CLFScripts/SRC.js"), [
      "0xa866BAcF9b8cf8beFC424Ec1EA253c0Ee7240118", // contractAddress
      "0x1ab32e9ea01849048bfb59996e02f0082df9298550249d7c6cefec78e7e24cd8", // ccipMessageId
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
      "1000000000000000000", // amount
      process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA, // srcChainSelector
      process.env.CL_CCIP_CHAIN_SELECTOR_FUJI, // dstChainSelector
      process.env.CCIPBNM_ARBITRUM_SEPOLIA, // token
    ]);

    // await simulate(path.join(__dirname, "./CLFScripts/DST.min.js"), [
    //   "0x4200A2257C399C1223f8F3122971eb6fafaaA976", // srcContractAddress
    //   "0xb47d30d9660222539498f85cefc5337257f8e0ebeabbce312108f218555ced50", // messageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   process.env.CCIPBNM_FUJI, // token
    //   "1000000000000000", // amount
    //   process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // dstChainSelector
    //   process.env.CL_CCIP_CHAIN_SELECTOR_FUJI, // chain selector to get the logs from
    // ]);
  });

export default {};
