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
    // console.log(decodeResult(responseBytesHexstring, "uint256"));
  }
}

/* run with: bunx hardhat clf-simulate-script */
task("clf-script-simulate", "Executes the JavaScript source code locally")
  // .addOptionalParam("path", "Path to script file", `${__dirname}/../Functions-request-config.js`, types.string)
  .setAction(async (taskArgs, hre) => {
    // execSync(`bunx hardhat clf-script-build --file SRC.js`, { stdio: "inherit" });
    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/SRC.min.js"), [
    //   process.env.CONCEROCCIP_OPTIMISM_SEPOLIA, // contractAddress
    //   "0x5315f93854194ca639615651c5662cf39a77308927ebe7d31c9e970958687a49", // ccipMessageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "100000000000000000", // amount
    //   process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // srcChainSelector
    //   process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA, // dstChainSelector
    //   "0", // token
    //   "0xA65233", // blockNumber
    // ]);

    execSync(`bunx hardhat clf-script-build --file DST.js`, { stdio: "inherit" });
    await simulate(path.join(__dirname, "../", "./CLFScripts/dist/DST.min.js"), [
      process.env.CONCEROCCIP_BASE_SEPOLIA, // srcContractAddress
      process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA, // srcChainSelector, chain to get logs from
      "0x92DA49", // blockNumber
      // event params:
      "0xcbb4574636f48c0490d6bee60231da8859441fd1db1dd398040dbdfaa2c8cdc8", // messageId
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
      "0", // token
      "40000000000000000", // amount
      "5224473277236331295", // dstChainSelector
    ]);
  });

export default {};
