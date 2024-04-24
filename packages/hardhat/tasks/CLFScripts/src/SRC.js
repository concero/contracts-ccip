/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// const secrets = {};
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/

const {createWalletClient, custom} = await import('npm:viem');
const {privateKeyToAccount} = await import('npm:viem/accounts');
const {sepolia, arbitrumSepolia, baseSepolia, optimismSepolia, avalancheFuji} = await import('npm:viem/chains');
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
			if (method === 'eth_estimateGas') return '0xC3500';
			if (method === 'eth_maxPriorityFeePerGas') return '0x0';
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
try {
	const hash = await walletClient.writeContract({
		abi,
		functionName: 'addUnconfirmedTX',
		address: contractAddress,
		args: [ccipMessageId, sender, recipient, amount, srcChainSelector, token, blockNumber],
	});
	if (hash) {
		if (typeof hash === 'string') {
			return Functions.encodeString(hash + 'str');
		} else if (typeof hash === 'number') {
			return Functions.encodeString('hashnum');
		} else if (typeof hash === 'bigint') {
			return Functions.encodeString('bigint');
		} else {
			return Functions.encodeString('wronghash');
		}
	} else {
		return Functions.encodeString('nohash');
	}
} catch (err) {
	if (typeof err === 'string') {
		return Functions.encodeString(err);
	} else if (typeof err === 'object') {
		if (Object.keys(err).length) {
			return Functions.encodeString('objerr');
		} else {
			return Functions.encodeString('noobjerr');
		}
	} else {
		return Functions.encodeString('err');
	}
}
