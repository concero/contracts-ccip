/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/

const ethers = await import('npm:ethers@6.10.0');
const [
	dstContractAddress,
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
		urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
		chainId: '0xa869',
	},
	'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
		urls: [
			`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			'https://ethereum-sepolia-rpc.publicnode.com',
			'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
		],
		chainId: '0xaa36a7',
	},
	'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
		urls: [
			`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
			'https://arbitrum-sepolia-rpc.publicnode.com',
		],
		chainId: '0x66eee',
	},
	'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
		urls: [
			`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
			'https://base-sepolia.blockpi.network/v1/rpc/public',
			'https://base-sepolia-rpc.publicnode.com',
		],
		chainId: '0x14a34',
	},
	'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
		urls: [
			`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			'https://optimism-sepolia.blockpi.network/v1/rpc/public',
			'https://optimism-sepolia-rpc.publicnode.com',
		],
		chainId: '0xaa37dc',
	},
};
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
let nonce = 0;
let retriesLimit = 3;
let retries = 0;
let gasPrice;
let maxPriorityFeePerGas;

const sendTransaction = async (contract, signer, txOptions) => {
	try {
		try {
			const transaction = await contract.transactions(ccipMessageId);
			if (transaction[1] !== '0x0000000000000000000000000000000000000000') {
				return Functions.encodeString(`${ccipMessageId} already exists`);
			}
		} catch {}
		await contract.addUnconfirmedTX(
			ccipMessageId,
			sender,
			recipient,
			amount,
			srcChainSelector,
			token,
			blockNumber,
			txOptions,
		);
	} catch (err) {
		console.log(err.code, ' ', retries, nonce);
		if (retries >= retriesLimit) {
			throw new Error('retries reached the limit ' + err.message.slice(0, 200));
		}
		if (err.code === 'NONCE_EXPIRED') {
			await sleep(1000);
			retries++;
			await sendTransaction(contract, signer, {
				...txOptions,
				nonce: nonce++,
			});
		}
		throw new Error(err.message.slice(0, 255));
	}
};
try {
	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
			if (payload.method === 'eth_estimateGas') {
				return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}];
			}
			if (payload.method === 'eth_chainId') {
				return [{jsonrpc: '2.0', id: payload.id, result: chainSelectors[dstChainSelector].chainId}];
			}
			if (
				payload[0]?.method === 'eth_gasPrice' &&
				payload[1].method === 'eth_maxPriorityFeePerGas' &&
				payload.length === 2
			) {
				return [
					{jsonrpc: '2.0', id: payload[0].id, result: gasPrice, method: 'eth_gasPrice'},
					{jsonrpc: '2.0', id: payload[1].id, result: maxPriorityFeePerGas, method: 'eth_maxPriorityFeePerGas'},
				];
			}
			if (payload[0]?.id === 1 && payload[0].method === 'eth_chainId' && payload[1].id === 2 && payload.length === 2) {
				return [
					{jsonrpc: '2.0', method: 'eth_chainId', id: 1, result: chainSelectors[dstChainSelector].chainId},
					{jsonrpc: '2.0', method: 'eth_getBlockByNumber', id: 2, result: chainSelectors[dstChainSelector].chainId},
				];
			}
			let resp = await fetch(this.url, {
				method: 'POST',
				headers: {'Content-Type': 'application/json'},
				body: JSON.stringify(payload),
			});
			const res = await resp.json();
			if (res.length === undefined) {
				return [res];
			}
			return res;
		}
	}
	const fallbackProviders = chainSelectors[dstChainSelector].urls.map(url => {
		return {
			provider: new FunctionsJsonRpcProvider(url),
			priority: Math.random(),
			stallTimeout: 5000,
			weight: 1,
		};
	});
	const provider = new ethers.FallbackProvider(fallbackProviders, null, {quorum: 1});
	const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
	const signer = wallet.connect(provider);
	const abi = [
		'function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external',
		'function transactions(bytes32) view returns (bytes32, address, address, uint256, uint8, uint64, bool)',
	];
	const contract = new ethers.Contract(dstContractAddress, abi, signer);
	const feeData = await provider.getFeeData();
	nonce = await provider.getTransactionCount(wallet.address);
	gasPrice = feeData.gasPrice;
	maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
	await sendTransaction(contract, signer, {
		gasPrice,
		nonce,
	});

	const srcChainProvider = new FunctionsJsonRpcProvider(chainSelectors[srcChainSelector].urls[0]);
	const srcGasPrice = Functions.encodeUint256(BigInt((await provider.getFeeData()).gasPrice));
	const dstGasPrice = Functions.encodeUint256(BigInt(gasPrice));
	const encodedDstChainSelector = Functions.encodeUint256(BigInt(dstChainSelector));
	const res = new Uint8Array(srcGasPrice.length + dstGasPrice.length + encodedDstChainSelector.length);
	res.set(srcGasPrice);
	res.set(dstGasPrice, srcGasPrice.length);
	res.set(encodedDstChainSelector, srcGasPrice.length + dstGasPrice.length);

	return res;
} catch (error) {
	throw new Error(error.message.slice(0, 255));
}
