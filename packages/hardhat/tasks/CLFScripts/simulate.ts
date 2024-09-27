import {task, types} from 'hardhat/config';
import fs from 'fs';
import secrets from '../../constants/CLFSecrets';
import CLFSimulationConfig from '../../constants/CLFSimulationConfig';
import {execSync} from 'child_process';
import getHashSum from '../../utils/getHashSum';
import {
	collectLuqiudytyCodeUrl,
	ethersV6CodeUrl,
	infraSrcJsCodeUrl,
	parentPoolDistributeLiqJsCodeUrl,
} from '../../constants/functionsJsCodeUrls';
import {getEnvVar} from '../../utils';
import {parseUnits} from 'viem';

const {simulateScript} = require('@chainlink/functions-toolkit');

const path = require('path');
const process = require('process');

async function simulate(pathToFile, args) {
	if (!fs.existsSync(pathToFile)) return console.error(`File not found: ${pathToFile}`);
	console.log('Simulating script:', pathToFile);

	let promises = [];
	for (let i = 0; i < 1; i++) {
		promises.push(
			simulateScript({
				source: fs.readFileSync(pathToFile, 'utf8'),
				bytesArgs: args,
				secrets,
				...CLFSimulationConfig,
			}),
		);
	}

	let results = await Promise.all(promises);

	for (const result of results) {
		const {errorString, capturedTerminalOutput, responseBytesHexstring} = result;

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
		}
	}
}

task('clf-script-simulate', 'Executes the JavaScript source code locally')
	.addParam('function', 'Path to script file', 'pool_get_total_balance', types.string)
	.setAction(async (taskArgs, hre) => {
		execSync(`bunx hardhat clf-script-build --all`, {stdio: 'inherit'});

		if (taskArgs.function === 'infra_src') {
			await simulate(path.join(__dirname, '../', './CLFScripts/dist/infra/eval.min.js'), [
				getHashSum(await (await fetch(infraSrcJsCodeUrl)).text()),
				getHashSum(await (await fetch(ethersV6CodeUrl)).text()),
				'0x0',
				getEnvVar('CONCERO_INFRA_PROXY_POLYGON'), // dst contractAddress
				'0xf721b113e0a0401ba87f48aff9801c78f037cab36cb43c72bd115ccec7845d27', // ccipMessageId
				'0x70E73f067a1fC9FE6D53151bd271715811746d3a', // sender
				'0x70E73f067a1fC9FE6D53151bd271715811746d3a', // recipient
				'0x' + 100000000000000000n.toString(16), // amount
				'0x' + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_BASE).toString(16), // srcChainSelector
				'0x' + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_POLYGON).toString(16), // dstChainSelector
				'0x' + 1n.toString(16), // token
				'0xA65233', // blockNumber
				'0x00', //dst swap data
			]);
		} else if (taskArgs.function === 'infra_dst') {
			await simulate(path.join(__dirname, '../', './CLFScripts/dist/infra/DST.min.js'), [
				'0x03a10af5b94376dd622652937371b52b0df82f0a3f0e2ad68a0e6384911fd7bd',
				'0x984202f6c36a048a80e993557555488e5ae13ff86f2dfbcde698aacd0a7d4eb4', // ethers hash sum
				'0x1',
				process.env.CONCERO_INFRA_PROXY_ARBITRUM_SEPOLIA, // srcContractAddress
				'0x' + BigInt(process.env.CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA).toString(16), // srcChainSelector, chain to get logs from
				'0x6748AE', // blockNumber
				// event params:
				'0x2e36844a859b5802e47c2b5cd9ae5f2f424e83c13fc5919b8bf3d6e641e43c95', // conceroBridgeId
				'0xdddddb8a8e41c194ac6542a0ad7ba663a72741e0', // sender
				'0xdddddb8a8e41c194ac6542a0ad7ba663a72741e0', // recipient
				'0x' + 1n.toString(16), // token
				'0x' + parseUnits('1', 6), // amount
				'0x' + process.env.CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA.toString(16), // dstChainSelector
			]);
		} else if (taskArgs.function === 'pool_get_total_balance') {
			await simulate(path.join(__dirname, '../', './CLFScripts/dist/pool/getTotalBalance.min.js'), [
				'0xef64cf53063700bbbd8e42b0282d3d8579aac289ea03f826cf16f9bd96c7703a', // srcJsHashSum
				'0x984202f6c36a048a80e993557555488e5ae13ff86f2dfbcde698aacd0a7d4eb4', // ethers hash sum
			]);
		} else if (taskArgs.function === 'automation') {
			await simulate(path.join(__dirname, '../', './CLFScripts/dist/pool/collectLiquidity.min.js'), [
				getHashSum(await (await fetch(collectLuqiudytyCodeUrl)).text()),
				getHashSum(await (await fetch(ethersV6CodeUrl)).text()),
				'0xDddDDb8a8E41C194ac6542a0Ad7bA663A72741E0',
				'0x147B0',
				'0x3e63da41d93846072a115187efd804333da52256b8ec17e9c05163d6903d561d',
			]);
		} else if (taskArgs.function === 'pool_distribute_liq') {
			await simulate(path.join(__dirname, '../', './CLFScripts/dist/pool/distributeLiquidity.min.js'), [
				getHashSum(await (await fetch(parentPoolDistributeLiqJsCodeUrl)).text()),
				getHashSum(await (await fetch(ethersV6CodeUrl)).text()),
				'0x1', // functions req type
				'0x383a1891ae1915b1',
				'0x05f8cc312ae3687e5581353da9c5889b92d232f7776c8b81dc234fb330fda265', // req id
				'0x1', // distribute liq type
			]);
		}
	});

export default {};
