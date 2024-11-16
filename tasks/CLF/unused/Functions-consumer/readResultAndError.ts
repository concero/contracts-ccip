import { task, types } from "hardhat/config";
import { decodeResult } from "@chainlink/functions-toolkit";
import path from "path";
import process from "process";

// run with: bunx hardhat clf-read --contract 0x...
task(
  "clf-read",
  "Reads the latest response (or error) returned to a FunctionsConsumer or AutomatedFunctionsConsumer consumer contract",
)
  .addParam("contract", "Address of the consumer contract to read")
  // .addOptionalParam("configpath", "Path to Functions request config file", `${__dirname}/../../Functions-request-config.js`, types.string)
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
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
      const configPath = path.isAbsolute(taskArgs.configpath)
        ? taskArgs.configpath
        : path.join(process.cwd(), taskArgs.configpath);
      const requestConfig = await import(configPath); // Dynamically import the config file
      const decodedResult = decodeResult(latestResponse, requestConfig.expectedReturnType).toString();
      console.log(
        `\nOn-chain response represented as a hex string: ${latestResponse}\nDecoded response: ${decodedResult}`,
      );
    } else if (latestResponse === "0x") {
      console.log("Empty response: ", latestResponse);
    }
  });

export default {};
