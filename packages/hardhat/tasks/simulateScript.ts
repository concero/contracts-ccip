import { task } from "hardhat/config";
import fs from "fs";
import secrets from "../constants/CLFSecrets";
import CLFSimulationConfig from "../constants/CLFSimulationConfig";
import { execSync } from "child_process";

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
  // .addOptionalParam("path", "Path to script file", `${__dirname}/../Functions-request-config.js`, types.string)
  .setAction(async (taskArgs, hre) => {
    execSync(`bunx hardhat functions-build-script --path SRC.js`, { stdio: "inherit" });
    await simulate(path.join(__dirname, "./CLFScripts/dist/SRC.js"), [
      "0x043E2d11CA3DB1cb22D8c54c93885F1dd9B11DD1", // contractAddress
      "0xcfecf49b293e528d0cd9b18892c481d83346d38d535ebaf0086805115abf6aa2", // ccipMessageId
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
      "1000000000000000000", // amount
      process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // srcChainSelector
      process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA, // dstChainSelector
      process.env.CCIPBNM_ARBITRUM_SEPOLIA, // token
      "0x210bb76", // blockNumber
    ]);

    // execSync(`bunx hardhat functions-build-script --path DST.js`, { stdio: "inherit" });
    // await simulate(path.join(__dirname, "./CLFScripts/dist/DST.min.js"), [
    //   "0xc28aa2112f15E3B66E0d801ed338E8477c375B50", // srcContractAddress
    //   process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA, // srcChainSelector, chain to get logs from
    //   "0xA65233", // blockNumber
    //   // event params:
    //   "0x283a9b5dda70401944eae78ade21a7f6f433b5cfdb0c87130c35e86a151fc822", // messageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "0", // token
    //   "100000000000000000", // amount
    //   "10344971235874465080", // dstChainSelector
    // ]);
  });

export default {};
