import { task } from "hardhat/config";
import fs from "fs";
import secrets from "../../constants/CLFSecrets";
import CLFSimulationConfig from "../../constants/CLFSimulationConfig";
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
task("clf-script-simulate", "Executes the JavaScript source code locally")
  // .addOptionalParam("path", "Path to script file", `${__dirname}/../Functions-request-config.js`, types.string)
  .setAction(async (taskArgs, hre) => {
    execSync(`bunx hardhat clf-script-build --path test.js`, { stdio: "inherit" });
    await simulate(path.join(__dirname, "../CLFScripts/dist/test.min.js"), []);
    // execSync(`bunx hardhat functions-build-script --path SRC.js`, { stdio: "inherit" });
    // await simulate(path.join(__dirname, "./CLFScripts/dist/SRC.min.js"), [
    //   process.env.CONCEROCCIP_OPTIMISM_SEPOLIA, // contractAddress
    //   "0x4395f93854194ca639615657c5662cf39a77308927ebe7d31c9e970958687a49", // ccipMessageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "100000000000000000", // amount
    //   process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // srcChainSelector
    //   process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA, // dstChainSelector
    //   "0", // token
    //   "0xA65233", // blockNumber
    // ]);

    // execSync(`bunx hardhat clf-script-build --path DST.js`, { stdio: "inherit" });
    // await simulate(path.join(__dirname, "../CLFScripts/dist/DST.min.js"), [
    //   process.env.CONCEROCCIP_BASE_SEPOLIA, // srcContractAddress
    //   process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA, // srcChainSelector, chain to get logs from
    //   "0x915F2A", // blockNumber
    //   // event params:
    //   "0x70cc2bb9a6299720c05062ba9c0f4830212cf13825517983d4a94c7ccf986aff", // messageId
    //   "0xe3e2c69de286dc2d2b73e0600260c0552ea0ee02", // sender
    //   "0xe3e2c69de286dc2d2b73e0600260c0552ea0ee02", // recipient
    //   "0", // token
    //   "100000000000000000", // amount
    //   process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA, // dstChainSelector
    // ]);
  });

export default {};
