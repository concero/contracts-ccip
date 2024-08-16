(async () => {
	const chainSelectors = {
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0x82F144741b9AD801FBb2fA52D3ee7B7e6e93B204',
		},
		[`0x${BigInt('14767482510784806043').toString(16)}`]: {
			urls: [
				`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
			],
			chainId: '0xa869',
			usdcAddress: '0x5425890298aed601595a70ab815c96711a31bc65',
			poolAddress: '0x3c69809aC32618F4E8842729b63A4679d1971aA5',
		},
		[`0x${BigInt('10344971235874465080').toString(16)}`]: {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
			],
			chainId: '0x14a34',
			usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
			poolAddress: '0x5a42824F47257090A20894E18b3271ADbE6Ab228',
		},
	};
	const baseChainSelector = `0x${BigInt('10344971235874465080').toString(16)}`;
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
		const pool = new ethers.Contract('0x0AE1B2730066AD46481ab0a5fd2B5893f8aBa323', poolAbi, baseProvider);
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
		const ccipLines = depositsOnTheWay.map(line => {
			const [conceroId, chainSelector, ccipMessageId] = line;
			return {conceroId, chainSelector, ccipMessageId};
		});
		if (ccipLines.length) {
			try {
				const logs = await getChildPoolsCcipLogs(ccipLines);
				conceroIds = getCompletedConceroIdsByLogs(logs, ccipLines);
			} catch (e) {
				console.error(e);
			}
		}
	}
	return packResult(totalBalance, conceroIds);
})();
