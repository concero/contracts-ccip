/*
COMPATIBLE WITH NODE v18.20.1 or earlier
run with: node simulate.js
*/

const {simulateScript} = require('@chainlink/functions-toolkit');
const fs = require('node:fs');
const dotenv = require('dotenv');
const decodeHexString = require('./utils/decodeHexString');
dotenv.config({path: '../.env'});
dotenv.config({path: '../.env.clf'});
dotenv.config({path: '../.env.clccip'});
dotenv.config({path: '../.env.tokens'});

const secrets = {
	WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
	INFURA_API_KEY: process.env.INFURA_API_KEY,
};

async function simulate(pathToFile, args) {
	const {responseBytesHexstring, errorString, capturedTerminalOutput} = await simulateScript({
		source: fs.readFileSync(pathToFile, 'utf8'),
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

//
// simulate('./dist/SRC.js', [
// 	'0xa866BAcF9b8cf8beFC424Ec1EA253c0Ee7240118', // contractAddress
// 	'0x1ab32e9ea01849048bfb59996e02f0082df9298550249d7c6cefec78e7e24cd8', // ccipMessageId
// 	'0x70E73f067a1fC9FE6D53151bd271715811746d3a', // sender
// 	'0x70E73f067a1fC9FE6D53151bd271715811746d3a', // recipient
// 	'1000000000000000000', // amount
// 	process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // srcChainSelector
// 	process.env.CL_CCIP_CHAIN_SELECTOR_FUJI, // dstChainSelector
// 	process.env.CCIPBNM_ARBITRUM_SEPOLIA, // token
// ]);

simulate('./dist/DST.js', [
	'0x4200A2257C399C1223f8F3122971eb6fafaaA976', // srcContractAddress
	'0xb47d30d9660222539498f85cefc5337257f8e0ebeabbce312108f218555ced50', // messageId
	'0x70E73f067a1fC9FE6D53151bd271715811746d3a', // sender
	'0x70E73f067a1fC9FE6D53151bd271715811746d3a', // recipient
	process.env.CCIPBNM_FUJI, // token
	'1000000000000000', // amount
	process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA, // dstChainSelector
	process.env.CL_CCIP_CHAIN_SELECTOR_FUJI, // chain selector to get the logs from
]);
