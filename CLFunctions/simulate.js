/*
COMPATIBLE WITH NODE v18.20.1 or earlier
run with: node simulate.js
*/

const { simulateScript } = require("@chainlink/functions-toolkit");
const fs = require("node:fs");
const dotenv = require("dotenv");
const decodeHexString = require("./utils/decodeHexString");
dotenv.config({ path: "../.env" });

const secrets = {
  WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
  INFURA_API_KEY: process.env.INFURA_API_KEY,
};

async function simulate(pathToFile, args) {
  const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript({
    source: fs.readFileSync(pathToFile, "utf8"),
    args,
    secrets,
    maxOnChainResponseBytes: 256,
    maxExecutionTimeMs: 100000,
    maxMemoryUsageMb: 128,
    numAllowedQueries: 5,
    maxQueryDurationMs: 10000,
    maxQueryUrlLength: 2048,
    maxQueryRequestBytes: 2048,
    maxQueryResponseBytes: 2097152,
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
    console.log(responseBytesHexstring);
  }
}

// simulate("./CLF_src/CLFsrcProd.js", [
//   "0xa866BAcF9b8cf8beFC424Ec1EA253c0Ee7240118",
//   "0x1ab32e9ea01849048bfb59996e02f0082df9298550249d7c6cefec78e7e24cd8",
//   "0x70E73f067a1fC9FE6D53151bd271715811746d3a",
//   "0x70E73f067a1fC9FE6D53151bd271715811746d3a",
//   "1000000000000000000",
//   "14767482510784806043",
//   "12532609583862916517",
//   "0x9999f7Fea5938fD3b1E26`A12c3f2fb024e194f97",
// ]);
simulate("./utils/test.js", []);
// simulate('./CLF_dst/CLFunctionsDST.js', [
//  '0x4200A2257C399C1223f8F3122971eb6fafaaA976',
//  '0xb47d30d9660222539498f85cefc5337257f8e0ebeabbce312108f218555ced50',
//  '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
//  '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
//  '0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40',
//  '1000000000000000',
//  '12532609583862916517',
//  '14767482510784806043',
// ]);
