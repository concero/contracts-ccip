/*
COMPATIBLE WITH NODE v18.20.1 or earlier
run with: node simulate.js
*/

const { simulateScript } = require('@chainlink/functions-toolkit');
const fs = require('node:fs');
const dotenv = require('dotenv');
const decodeHexString = require('./utils/decodeHexString');
dotenv.config();

const secrets = {
  WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
  INFURA_API_KEY: process.env.INFURA_API_KEY,
};

async function simulate() {
  const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript({
    source: fs.readFileSync('./CLF_src/CLFsrc-CUSTOM-TRANSPORT-FUNCTIONS-SIMULATION.js', 'utf8'),
    // args,
    secrets,
    // maxOnChainResponseBytes: 256,
    // maxExecutionTimeMs: 100000,
    // maxMemoryUsageMb: 128,
    numAllowedQueries: 2,
    // maxQueryDurationMs: 10000,
    // maxQueryUrlLength: 2048,
    // maxQueryRequestBytes: 2048,
    // maxQueryResponseBytes: 2097152,
  });

  if (errorString) {
    console.log('CAPTURED ERROR:');
    console.log(errorString);
  }

  if (capturedTerminalOutput) {
    console.log('CAPTURED TERMINAL OUTPUT:');
    console.log(capturedTerminalOutput);
  }

  if (responseBytesHexstring) {
    console.log('RESPONSE BYTES HEXSTRING:');
    console.log(responseBytesHexstring);
    console.log('RESPONSE BYTES DECODED:');
    console.log(decodeHexString(responseBytesHexstring));
  }
}

simulate();
