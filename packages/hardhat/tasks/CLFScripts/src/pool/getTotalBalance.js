const ethers = await import('npm:ethers@6.10.0');

return (async () => {
	const chainSelectors = {
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				// 'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				// 'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '${USDC_ARBITRUM_SEPOLIA}',
			poolAddress: '${CHILD_POOL_PROXY_ARBITRUM_SEPOLIA}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
			urls: [
				`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
				// 'https://avalanche-fuji-c-chain-rpc.publicnode.com',
				// 'https://avalanche-fuji.blockpi.network/v1/rpc/public',
			],
			chainId: '0xa869',
			usdcAddress: '${USDC_FUJI}',
			poolAddress: '${CHILD_POOL_PROXY_FUJI}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
				// 'https://base-sepolia.blockpi.network/v1/rpc/public',
				// 'https://base-sepolia-rpc.publicnode.com',
			],
			chainId: '0x14a34',
			usdcAddress: '${USDC_BASE_SEPOLIA}',
			poolAddress: '${PARENT_POOL_PROXY_BASE_SEPOLIA}',
		},

		// mainnets
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
		// 	urls: [`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
		// 	chainId: '0xa4b1',
		// 	usdcAddress: '${USDC_ARBITRUM}',
		// 	poolAddress: '${CHILD_POOL_PROXY_ARBITRUM}',
		// },
		//
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
		// 	urls: [`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
		// 	chainId: '0x89',
		// 	usdcAddress: '${USDC_POLYGON}',
		// 	poolAddress: '${CHILD_POOL_PROXY_POLYGON}',
		// },
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
		// 	urls: [`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
		// 	chainId: '0xa86a',
		// 	usdcAddress: '${USDC_AVALANCHE}',
		// 	poolAddress: '${CHILD_POOL_PROXY_AVALANCHE}',
		// },
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`]: {
		// 	urls: [`https://base-mainnet.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`],
		// 	chainId: '0x2105',
		// 	usdcAddress: '${USDC_BASE}',
		// 	poolAddress: '${PARENT_POOL_PROXY_BASE}',
		// },
	};

	// const baseChainSelector = `0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE}').toString(16)}`;
	const baseChainSelector = `0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`;
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = [
		'function s_loansInUse() external view returns (uint256)',
		'function getDepositsOnTheWay() external view returns (tuple(uint64, bytes32, uint256)[150] memory)',
	];

	const findChainIdByUrl = url => {
		for (const chain in chainSelectors) {
			if (chainSelectors[chain].urls.includes(url)) return chainSelectors[chain].chainId;
		}
		return null;
	};

	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
			if (payload.method === 'eth_chainId') {
				const _chainId = findChainIdByUrl(this.url);
				return [{jsonrpc: '2.0', id: payload.id, result: _chainId}];
			}
			let resp = await fetch(this.url, {
				method: 'POST',
				headers: {'Content-Type': 'application/json'},
				body: JSON.stringify(payload),
			});
			const res = await resp.json();
			if (res.length === undefined) return [res];
			return res;
		}
	}

	const getProviderByChainSelector = _chainSelector => {
		const urls = chainSelectors[_chainSelector].urls;
		const url = urls[Math.floor(Math.random() * urls.length)];
		return new FunctionsJsonRpcProvider(url);
	};

	const baseProvider = getProviderByChainSelector(baseChainSelector);

	const getBaseDepositsOneTheWay = async () => {
		// const pool = new ethers.Contract('${PARENT_POOL_PROXY_BASE}', poolAbi, baseProvider);
		const pool = new ethers.Contract('${PARENT_POOL_PROXY_BASE_SEPOLIA}', poolAbi, baseProvider);
		const depositsOnTheWay = await pool.getDepositsOnTheWay();
		return depositsOnTheWay.reduce((acc, [chainSelector, ccipMessageId, amount], index) => {
			if (ccipMessageId !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
				acc.push({index, chainSelector, ccipMessageId, amount});
			}
			return acc;
		}, []);
	};

	const getChildPoolsCcipLogs = ccipLines => {
		const ethersId = ethers.id('ConceroChildPool_CCIPReceived(bytes32,uint64,address,address,uint256)');
		const promises = [];

		for (const chainSelectorsKey in chainSelectors) {
			const reqFromLines = ccipLines.filter(line => {
				const hexChainSelector = `0x${BigInt(line.chainSelector).toString(16)}`.toLowerCase();
				return hexChainSelector === chainSelectorsKey;
			});

			if (!reqFromLines.length) continue;

			const provider = getProviderByChainSelector(chainSelectorsKey);

			for (const line of reqFromLines) {
				promises.push(
					provider.getLogs({
						address: chainSelectors[chainSelectorsKey].poolAddress,
						topics: [ethersId, line.ccipMessageId],
						fromBlock: 0,
						toBlock: 'latest',
					}),
				);
			}
		}

		return Promise.all(promises);
	};

	const getCompletedConceroIdsByLogs = (logs, ccipLines) => {
		if (!logs?.length) return [];
		const conceroIds = [];

		for (const log of logs) {
			if (!log.length) continue;
			const ccipMessageId = log[0].topics[1];
			const ccipLine = ccipLines.find(line => line.ccipMessageId.toLowerCase() === ccipMessageId.toLowerCase());
			conceroIds.push(ccipLine.index);
		}

		return conceroIds;
	};

	const packResult = (_totalBalance, _conceroIds) => {
		const result = new Uint8Array(32 + conceroIds.length + 1);
		const encodedTotalBalance = Functions.encodeUint256(_totalBalance);
		result.set(encodedTotalBalance, 0);
		if (_conceroIds.length) {
			for (let i = 0; i < _conceroIds.length; i++) {
				const encodedConceroId = new Uint8Array([Number(_conceroIds[i])]);
				result.set(encodedConceroId, 32 + i);
			}
		} else {
			result.set(new Uint8Array([0]), 32);
		}

		return result;
	};

	let promises = [];
	let totalBalance = 0n;

	for (const chain in chainSelectors) {
		if (chain.toLowerCase() === baseChainSelector.toLowerCase()) continue;

		const provider = getProviderByChainSelector(chain);
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		promises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
		promises.push(pool.s_loansInUse());
	}

	promises.push(getBaseDepositsOneTheWay());

	const results = await Promise.all(promises);

	for (let i = 0; i < results.length - 2; i += 2) {
		totalBalance += BigInt(results[i]) + BigInt(results[i + 1]);
	}

	const depositsOnTheWay = results[results.length - 1];
	let conceroIds = [];

	if (depositsOnTheWay.length) {
		// const ccipLines = depositsOnTheWay.map(line => {
		// 	const [conceroId, chainSelector, ccipMessageId] = line;
		// 	return {conceroId, chainSelector, ccipMessageId};
		// });

		if (depositsOnTheWay.length) {
			try {
				const logs = await getChildPoolsCcipLogs(depositsOnTheWay);
				conceroIds = getCompletedConceroIdsByLogs(logs, depositsOnTheWay);
			} catch (e) {
				console.error(e);
			}
		}
	}

	return packResult(totalBalance, conceroIds);
})();
