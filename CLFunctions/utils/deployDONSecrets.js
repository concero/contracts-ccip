const ethers = require('ethers');
const SecretsManager = require('@chainlink/functions-toolkit').SecretsManager;
const dotenv = require('dotenv');
import chains from '../../packages/hardhat/constants/CLFChains';

dotenv.config({path: '../.env'});
dotenv.config({path: '../.env.clf'});
dotenv.config({path: '../.env.clccip'});
dotenv.config({path: '../.env.tokens'});

const args = process.argv.slice(2);
const chainToDeployTo = args[0];

if (args.length === 0) throw new Error('Please provide the chain to deploy to as an argument.');
if (!chains[chainToDeployTo]) throw new Error(`Chain ${chainToDeployTo} not supported.`);

const privateKey = process.env.DEPLOYER_PRIVATE_KEY;
const slotId = 0;
const minutesUntilExpiration = 4320;

const secrets = {
	INFURA_API_KEY: process.env.INFURA_API_KEY,
	WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY,
};

const deploySecrets = async (functionsRouterAddress, donId, rpcUrl) => {
	const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
	const wallet = new ethers.Wallet(privateKey);
	const signer = wallet.connect(provider);
	const gatewayUrls = [
		'https://01.functions-gateway.testnet.chain.link/',
		'https://02.functions-gateway.testnet.chain.link/',
	];
	const secretsManager = new SecretsManager({signer, functionsRouterAddress, donId});
	await secretsManager.initialize();
	const {encryptedSecrets} = await secretsManager.encryptSecrets(secrets);
	console.log(`Uploading secrets to: ${gatewayUrls}.`);

	const {version, success} = await secretsManager.uploadEncryptedSecretsToDON({
		encryptedSecretsHexstring: encryptedSecrets,
		gatewayUrls,
		slotId,
		minutesUntilExpiration,
	});

	if (!success) throw new Error(`Encrypted secrets not uploaded to ${gatewayUrls}`);
	console.log(`\n✅ Secrets uploaded to gateways ${gatewayUrls}! \nGateways response: `, version, success);
	const secretsEntriesForGateway = await secretsManager.listDONHostedEncryptedSecrets(gatewayUrls);
	console.log(JSON.stringify(secretsEntriesForGateway, null, 2));
};

deploySecrets(chains[chainToDeployTo].router, chains[chainToDeployTo].donId, chains[chainToDeployTo].rpcUrl).catch(
	err => {
		console.log('ERROR: ', err);
	},
);
