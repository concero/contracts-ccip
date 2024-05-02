/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// const secrets = {};
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/
//todo: use ethers because it doesn't crash
//todo: or destructure viem and paste its functions into the call
//prod: use eval and off-chain hosted code with shasum check
// check dep bundlers

// its only 4 nodes!

const {createWalletClient, custom} = await import('npm:viem@2.9.0');
const {privateKeyToAccount} = await import('npm:viem@2.9.0/accounts');
const {sepolia, arbitrumSepolia, baseSepolia, optimismSepolia, avalancheFuji} = await import('npm:viem@2.9.0/chains');
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
//todo: use bytes.args
// math random is ok?
const chainSelectors = {
	'${CL_CCIP_CHAIN_SELECTOR_FUJI}': {
		url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
		chain: avalancheFuji,
	},
	'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
		url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		chain: sepolia,
	},
	'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
		url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		chain: arbitrumSepolia,
	},
	'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
		url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
		chain: baseSepolia,
	},
	'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
		url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		chain: optimismSepolia,
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
const account = privateKeyToAccount('0x' + secrets.WALLET_PRIVATE_KEY);
const walletClient = createWalletClient({
	account,
	chain: chainSelectors[dstChainSelector].chain,
	transport: custom({
		async request({method, params}) {
			if (method === 'eth_chainId') return chainSelectors[dstChainSelector].chain.id;
			if (method === 'eth_estimateGas') return '0x1e8480';
			if (method === 'eth_maxPriorityFeePerGas') return '0x3b9aca00';
			const response = await Functions.makeHttpRequest({
				url: chainSelectors[dstChainSelector].url,
				method: 'post',
				headers: {'Content-Type': 'application/json'},
				data: {jsonrpc: '2.0', id: 1, method, params},
			});
			return response.data.result;
		},
	}),
});
const hash = await walletClient.writeContract({
	abi,
	functionName: 'addUnconfirmedTX',
	address: contractAddress,
	args: [ccipMessageId, sender, recipient, amount, BigInt(srcChainSelector), token, blockNumber],
});
// todo convert to a uint8 array
return Functions.encodeString(typeof hash);
//todo: trycatch to trim errors
