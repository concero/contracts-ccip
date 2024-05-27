"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_1 = require("hardhat/config");
const fs_1 = __importDefault(require("fs"));
const CLFSecrets_1 = __importDefault(require("../../constants/CLFSecrets"));
const CLFSimulationConfig_1 = __importDefault(require("../../constants/CLFSimulationConfig"));
const child_process_1 = require("child_process");
const { simulateScript, decodeResult } = require("@chainlink/functions-toolkit");
const path = require("path");
const process = require("process");
async function simulate(pathToFile, args) {
    if (!fs_1.default.existsSync(pathToFile))
        return console.error(`File not found: ${pathToFile}`);
    console.log("Simulating script:", pathToFile);
    const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript({
        source: fs_1.default.readFileSync(pathToFile, "utf8"),
        args,
        secrets: CLFSecrets_1.default,
        ...CLFSimulationConfig_1.default,
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
(0, config_1.task)("clf-script-simulate", "Executes the JavaScript source code locally")
    // .addOptionalParam("path", "Path to script file", `${__dirn ame}/../Functions-request-config.js`, types.string)
    .setAction(async (taskArgs, hre) => {
    (0, child_process_1.execSync)(`bunx hardhat clf-script-build --all`, { stdio: "inherit" });
    await simulate(path.join(__dirname, "../", "./CLFScripts/dist/eval.min.js"), [
        "0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124", // srcJsHashSum
        process.env.CONCEROCCIP_OPTIMISM_SEPOLIA, // contractAddress
        "0x5315f93854194ca639615651c5662cf39a77308927ebe7d31c9e970958687a49", // ccipMessageId
        "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
        "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
        "100000000000000000", // amount
        process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // srcChainSelector
        process.env.CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA, // dstChainSelector
        "0", // token
        "0xA65233", // blockNumber
    ]);
    // await simulate(path.join(__dirname, "../", "./CLFScripts/dist/eval.min.js"), [
    //   "0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173",
    //   process.env.CONCEROCCIP_BASE_SEPOLIA, // srcContractAddress
    //   process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA, // srcChainSelector, chain to get logs from
    //   "0x92DA49", // blockNumber
    //   // event params:
    //   "0xc957703fb298a67ab8077f691dbf4cdb137be8fd39bd4afab67ef847f99a74c8", // messageId
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // sender
    //   "0x70E73f067a1fC9FE6D53151bd271715811746d3a", // recipient
    //   "0", // token
    //   "40000000000000000", // amount
    //   "5224473277236331295", // dstChainSelector
    // ]);
});
exports.default = {};
