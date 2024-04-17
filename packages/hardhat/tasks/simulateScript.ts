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
    await simulate(path.join(__dirname, "./CLFScripts/dist/SRC.js"), [
      "0x10eE6447Ae2bC0eBa7EE187e8754De2438833C7c", // contractAddress
      "0xcfecf49b293e528d0cd9b18892c481d83346d38d535ebaf0086805115abf6aa2", // ccipMessageId
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
      "1000000000000000000", // amount
      process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // srcChainSelector
      process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA, // dstChainSelector
      process.env.CCIPBNM_ARBITRUM_SEPOLIA, // token
    ]);

    // await simulate(path.join(__dirname, "./CLFScripts/dist/DST.min.js"), [
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
