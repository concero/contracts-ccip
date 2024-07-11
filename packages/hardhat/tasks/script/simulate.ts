import { task } from "hardhat/config";
import fs from "fs";
import secrets from "../../constants/CLFSecrets";
import CLFSimulationConfig from "../../constants/CLFSimulationConfig";
import { execSync } from "child_process";
import getHashSum from "../../utils/getHashSum";
import { ethersV6CodeUrl, infraSrcJsCodeUrl } from "../../constants/functionsJsCodeUrls";

const { simulateScript, decodeResult } = require("@chainlink/functions-toolkit");

const path = require("path");
const process = require("process");

async function simulate(pathToFile, args) {
  if (!fs.existsSync(pathToFile)) return console.error(`File not found: ${pathToFile}`);
  console.log("Simulating script:", pathToFile);

  let promises = [];
  for (let i = 0; i < 4; i++) {
    promises.push(
      simulateScript({
        source: fs.readFileSync(pathToFile, "utf8"),
        bytesArgs: args,
        secrets,
        ...CLFSimulationConfig,
      }),
    );
  }

  let results = await Promise.all(promises);

  for (const result of results) {
    const { errorString, capturedTerminalOutput, responseBytesHexstring } = result;

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
    }
  }
}

/* run with: bunx hardhat clf-simulate-script */
task("clf-script-simulate", "Executes the JavaScript source code locally")
  // .addOptionalParam("path", "Path to script file", `${__dirn ame}/../Functions-request-config.js`, types.string)
  .setAction(async (taskArgs, hre) => {
    execSync(`bunx hardhat clf-script-build --all`, { stdio: "inherit" });

    await simulate(path.join(__dirname, "../", "./CLFScripts/dist/infra/eval.min.js"), [
      getHashSum(await (await fetch(infraSrcJsCodeUrl)).text()),
      getHashSum(await (await fetch(ethersV6CodeUrl)).text()),
      "0x0",
      process.env.CONCERO_PROXY_POLYGON, // contractAddress
      "0xf721b413e0a040abe87f48aff9801c78f037cab36cb43c72bd115ccec7845d27", // ccipMessageId
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
      "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
      "0x" + 100000000000000000n.toString(16), // amount
      "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON).toString(16), // srcChainSelector
      "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_BASE).toString(16), // dstChainSelector
      "0x" + 0n.toString(16), // token
      "0xA65233", // blockNumber
      "0xf721b413e0a040abe87f48aff9801c78f037cab36cb43c72bd115ccec7845d27",
    ]);

    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/eval.min.js"), [
    //   "0x1c5cf42d2b714c7f86edd64fb9b0c45b1fbd3dcac9831837d857f302833953e4", // srcJsHashSum
    //   "0x05f8cc312ae3687e5581353da9c5889b92d232f7776c8b81dc234fb330fda265", // ethers hash sum
    //   "0x0",
    //   // process.env.CONCERO_BRIDGE_OPTIMISM_SEPOLIA, // contractAddress
    //   "0x3055cC530B8cF18fD996545EC025C4e677a1dAa3", // contractAddress
    //   "0x5315f93154194ca637615651c5662cf39a77308927ebe7d31c9e970958681a49", // ccipMessageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "0x" + 100000000000000000n.toString(16), // amount
    //   "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA).toString(16), // srcChainSelector
    //   "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA).toString(16), // dstChainSelector
    //   "0x" + 0n.toString(16), // token
    //   "0xA65233", // blockNumber
    // ]);

    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/eval.min.js"), [
    //   "0xada5df165da01ec1249e7ae55303f8587fd50170729ed2b33a8b53be71f8d8ab",
    //   "0x05f8cc312ae3687e5581353da9c5889b92d232f7776c8b81dc234fb330fda265", // ethers hash sum
    //   "0x1",
    //   process.env.CONCERO_BRIDGE_BASE_SEPOLIA, // srcContractAddress
    //   "0x" + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA).toString(16), // srcChainSelector, chain to get logs from
    //   "0x92DA49", // blockNumber
    //   // event params:
    //   "0xc957703fb298a67ab8077f691dbf4cdb137be8fd39bd4afab67ef847f99a74c8", // messageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "0x" + 0n.toString(16), // token
    //   "0x" + 40000000000000000n.toString(16), // amount
    //   "0x" + 5224473277236331295n.toString(16), // dstChainSelector
    // ]);

    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/pool/parentPoolEval.min.js"), [
    //   "0xef64cf53063700bbbd8e42b0282d3d8579aac289ea03f826cf16f9bd96c7703a", // srcJsHashSum
    //   "0x984202f6c36a048a80e993557555488e5ae13ff86f2dfbcde698aacd0a7d4eb4", // ethers hash sum
    // ]);

    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/pool/automationEval.min.js"), [
    //   getHashSum(await (await fetch(automationsJsCodeUrl)).text()),
    //   getHashSum(await (await fetch(ethersV6CodeUrl)).text()),
    //   "0xDddDDb8a8E41C194ac6542a0Ad7bA663A72741E0",
    //   "0x186A0",
    // ]);
  });

export default {};
