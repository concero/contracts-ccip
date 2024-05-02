/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// const secrets = {};
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/

const ethers = await import('npm:ethers@6.10.0');

const [
	contractAddress,
	ccipMessageId,
	sender,
	recipient,
	amount,
	srcChainSelector,
	dstChainSelector,
	token,
	blockNumber,
] = args;
const chainSelectors = {
	'${CL_CCIP_CHAIN_SELECTOR_FUJI}': {
		url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
		url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
		url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
		url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
	},
	'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
		url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
	},
};
const abi = [
	{
		name: 'addUnconfirmedTX',
		type: 'function',
		inputs: [
			{type: 'bytes32', name: 'ccipMessageId'},
			{type: 'address', name: 'sender'},
			{type: 'address', name: 'recipient'},
			{type: 'uint256', name: 'amount'},
			{type: 'uint64', name: 'srcChainSelector'},
			{type: 'uint8', name: 'token'},
			{type: 'uint256', name: 'blockNumber'},
		],
		outputs: [],
	},
];
const signer = new ethers.Wallet(secrets.PRIVATE_KEY);
const contract = new ethers.Contract(contractAddress, abi, signer);
const tx = await contract.addUnconfirmedTX(
	ccipMessageId,
	sender,
	recipient,
	amount,
	srcChainSelector,
	token,
	blockNumber,
);
return Functions.encodeString(tx.hash);
