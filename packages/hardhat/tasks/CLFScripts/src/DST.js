try {
	const ethers = await import('npm:ethers@6.10.0');
	const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
	const [srcContractAddress, srcChainSelector, _, ...eventArgs] = args;
	const messageId = eventArgs[0];
	const chainMap = {
		'${CL_CCIP_CHAIN_SELECTOR_FUJI}': {
			urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
			confirmations: 3n,
			chainId: '0xa869',
		},
		'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
				'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
			],
			confirmations: 3n,
			chainId: '0xaa36a7',
		},
		'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			confirmations: 3n,
			chainId: '0x66eee',
		},
		'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
				'https://base-sepolia.blockpi.network/v1/rpc/public',
				'https://base-sepolia-rpc.publicnode.com',
			],
			confirmations: 3n,
			chainId: '0x14a34',
		},
		'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			confirmations: 3n,
			chainId: '0xaa37dc',
		},
	};

	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
			if (payload.method === 'eth_chainId') {
				return [{jsonrpc: '2.0', id: payload.id, result: chainMap[srcChainSelector].chainId}];
			}
			const resp = await fetch(this.url, {
				method: 'POST',
				headers: {'Content-Type': 'application/json'},
				body: JSON.stringify(payload),
			});
			const result = await resp.json();
			if (payload.length === undefined) {
				return [result];
			}
			return result;
		}
	}

	const fallBackProviders = chainMap[srcChainSelector].urls.map(url => {
		return {
			provider: new FunctionsJsonRpcProvider(url),
			priority: Math.random(),
			stallTimeout: 2000,
			weight: 1,
		};
	});

	const provider = new ethers.FallbackProvider(fallBackProviders, null, {quorum: 1});

	let latestBlockNumber = BigInt(await provider.getBlockNumber());
	const ethersId = ethers.id('CCIPSent(bytes32,address,address,uint8,uint256,uint64)');
	const logs = await provider.getLogs({
		address: srcContractAddress,
		topics: [ethersId, messageId],
		fromBlock: latestBlockNumber - 1000n,
		toBlock: latestBlockNumber,
	});

	if (!logs.length) {
		throw new Error('No logs found');
	}

	const log = logs[0];
	const abi = ['event CCIPSent(bytes32 indexed, address, address, uint8, uint256, uint64)'];
	const contract = new ethers.Interface(abi);
	const logData = {
		topics: [ethersId, log.topics[1]],
		data: log.data,
	};

	const decodedLog = contract.parseLog(logData);
	for (let i = 0; i < decodedLog.length; i++) {
		if (decodedLog.args[i].toString().toLowerCase() !== eventArgs[i].toString().toLowerCase()) {
			throw new Error('Message ID does not match the event log');
		}
	}

	const logBlockNumber = BigInt(log.blockNumber);
	while (latestBlockNumber - logBlockNumber < chainMap[srcChainSelector].confirmations) {
		latestBlockNumber = BigInt(await provider.getBlockNumber());
		await sleep(5000);
	}

	if (latestBlockNumber - logBlockNumber < chainMap[srcChainSelector].confirmations) {
		throw new Error('Not enough confirmations');
	}

	return Functions.encodeUint256(BigInt(messageId));
} catch (error) {
	throw new Error(error.message.slice(0, 255));
}
