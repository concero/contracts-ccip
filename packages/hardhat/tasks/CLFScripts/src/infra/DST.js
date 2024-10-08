(async () => {
	try {
		const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
		// todo: add dstSwapDataHashSum argument, compare with event from source
		const [_, __, ___, srcContractAddress, srcChainSelector, txBlockNumber, ...eventArgs] = bytesArgs;
		const messageId = eventArgs[0];
		const chainMap = {
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
				urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
				confirmations: 3n,
				chainId: '0xa869',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}').toString(16)}`]: {
				urls: [
					`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://ethereum-sepolia-rpc.publicnode.com',
					'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
				],
				confirmations: 3n,
				chainId: '0xaa36a7',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
				urls: [
					`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
					'https://arbitrum-sepolia-rpc.publicnode.com',
				],
				confirmations: 3n,
				chainId: '0x66eee',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`]: {
				urls: [
					`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
					'https://base-sepolia.blockpi.network/v1/rpc/public',
					'https://base-sepolia-rpc.publicnode.com',
				],
				confirmations: 3n,
				chainId: '0x14a34',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}').toString(16)}`]: {
				urls: [
					`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://optimism-sepolia.blockpi.network/v1/rpc/public',
					'https://optimism-sepolia-rpc.publicnode.com',
				],
				confirmations: 3n,
				chainId: '0xaa37dc',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY}').toString(16)}`]: {
				urls: [
					`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://polygon-amoy.blockpi.network/v1/rpc/public',
					'https://polygon-amoy-bor-rpc.publicnode.com',
				],
				confirmations: 3n,
				chainId: '0x13882',
			},

			// mainnets

			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
				urls: ['https://polygon-bor-rpc.publicnode.com', 'https://rpc.ankr.com/polygon'],
				confirmations: 3n,
				chainId: '0x89',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
				urls: ['https://arbitrum-rpc.publicnode.com', 'https://rpc.ankr.com/arbitrum'],
				confirmations: 3n,
				chainId: '0xa4b1',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`]: {
				urls: ['https://base-rpc.publicnode.com', 'https://rpc.ankr.com/base'],
				confirmations: 3n,
				chainId: '0x2105',
			},
			[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
				urls: ['https://avalanche-c-chain-rpc.publicnode.com', 'https://rpc.ankr.com/avalanche'],
				confirmations: 3n,
				chainId: '0xa86a',
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

		while (latestBlockNumber - BigInt(txBlockNumber) < chainMap[srcChainSelector].confirmations) {
			latestBlockNumber = BigInt(await provider.getBlockNumber());
			await sleep(5000);
		}

		if (latestBlockNumber - BigInt(txBlockNumber) < chainMap[srcChainSelector].confirmations) {
			throw new Error('Not enough confirmations');
		}

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

		return Functions.encodeUint256(BigInt(messageId));
	} catch (error) {
		throw new Error(error.message.slice(0, 255));
	}
})();
