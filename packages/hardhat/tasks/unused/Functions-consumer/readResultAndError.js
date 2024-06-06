"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const config_2 = require("hardhat/config");
const functions_toolkit_2 = require("@chainlink/functions-toolkit");
const path_1 = __importDefault(require("path"));
const process_1 = __importDefault(require("process"));
// run with: bunx hardhat clf-read --contract 0x...
(0, config_2.task)("clf-read", "Reads the latest response (or error) returned to a FunctionsConsumer or AutomatedFunctionsConsumer consumer contract")
    .addParam("contract", "Address of the consumer contract to read")
    // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
    .setAction(async (taskArgs) => {
    const { name } = hre.network;
    console.log(`Reading data from Functions consumer contract ${taskArgs.contract} on network ${name}`);
    const consumerContractFactory = await hre.ethers.getContractFactory("CFunctions");
    const consumerContract = await consumerContractFactory.attach(taskArgs.contract);
    let latestError = await consumerContract.s_lastError();
    if (latestError.length > 0 && latestError !== "0x") {
        const errorString = Buffer.from(latestError.slice(2), "hex").toString();
        console.log(`\nOn-chain error message: ${errorString}`);
    }
    let latestResponse = await consumerContract.s_lastResponse();
    if (latestResponse.length > 0 && latestResponse !== "0x") {
        const configPath = path_1.default.isAbsolute(taskArgs.configpath)
            ? taskArgs.configpath
            : path_1.default.join(process_1.default.cwd(), taskArgs.configpath);
        const requestConfig = await Promise.resolve(`${configPath}`).then(s => __importStar(require(s))); // Dynamically import the config file
        const decodedResult = (0, functions_toolkit_2.decodeResult)(latestResponse, requestConfig.expectedReturnType).toString();
        console.log(`\nOn-chain response represented as a hex string: ${latestResponse}\nDecoded response: ${decodedResult}`);
    }
    else if (latestResponse === "0x") {
        console.log("Empty response: ", latestResponse);
    }
});
exports.default = {};
