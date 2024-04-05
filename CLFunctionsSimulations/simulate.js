// const { simulateScript } = await import('npm:@chainlink/functions-toolkit');
const { simulateScript } = require('@chainlink/functions-toolkit');
const fs = require('node:fs');

//const [fromChainSelector, toChainSelector, token, amount, txHash, sender, receiver, blockHash] = args;
const fromChainSelector = '12532609583862916517';
const toChainSelector = '14767482510784806043';
const token = '0x326C977E6efc84E512bB9C30f76E30c160eD06FB';
const amount = '1000000000000000000';
const txHash = '0x5d2b4f7b1b6e5d3b4f6c';
const sender = '0x5d2b4f7b1b6e5d3b4f6c';
const receiver = '0x5d2b4f7b1b6e5d3b4f6c';
const blockHash = '0x5d2b4f7b1b6e5d3b4f6c';

const PROVIDER_API_KEY = '8acf47c71165427f8cee3a92fea12da2';
const args = [fromChainSelector, toChainSelector, token, amount, txHash, sender, receiver, blockHash];

const secrets = {
  WALLET_PRIVATE_KEY: '44c04f3751b5e35344400ab7f7e561c3b80c02c2f87de69a561ecbf6d0018896',
  INFURA_API_KEY: '8acf47c71165427f8cee3a92fea12da2',
};

async function simulateSRC() {
  const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript({
    source: fs.readFileSync('./CLFunctionSRC-CUSTOM-TRANSPORT-FUNCTIONS-SIMULATION.js', 'utf8'),
    args,
    secrets,
    // maxOnChainResponseBytes: 256,
    // maxExecutionTimeMs: 100000,
    // maxMemoryUsageMb: 128,
    // numAllowedQueries: 5,
    // maxQueryDurationMs: 10000,
    // maxQueryUrlLength: 2048,
    // maxQueryRequestBytes: 2048,
    // maxQueryResponseBytes: 2097152,
  });

  if (errorString) {
    console.error(errorString);
  }

  console.log(capturedTerminalOutput);
  console.log(responseBytesHexstring);
}

simulateSRC();
