const ethers = await import('npm:ethers@6.10.0');
return (async () => {
	const chainSelectors = {
		[`0x${BigInt('4949039107694359620').toString(16)}`]: {
			urls: [`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa4b1',
			usdcAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
			poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
		},
		[`0x${BigInt('4051577828743386545').toString(16)}`]: {
			urls: [`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0x89',
			usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
			poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
		},
		[`0x${BigInt('6433500567565415381').toString(16)}`]: {
			urls: [`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa86a',
			usdcAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
			poolAddress: '0x164c20A4E11cBE0d8B5e23F5EE35675890BE280d',
		},
		[`0x${BigInt('15971525489660198786').toString(16)}`]: {
			urls: [`https://base-mainnet.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`],
			chainId: '0x2105',
			usdcAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
			poolAddress: '0x0AE1B2730066AD46481ab0a5fd2B5893f8aBa323',
		},
	};
	const baseChainSelector = `0x${BigInt('15971525489660198786').toString(16)}`;
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = [
		'function s_loansInUse() external view returns (uint256)',
		'function getDepositsOnTheWay() external view returns (tuple(bytes1, uint64, bytes32, uint256)[] memory)',
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
	const getBaseDepositsOneTheWay = () => {
		const pool = new ethers.Contract('0x0AE1B2730066AD46481ab0a5fd2B5893f8aBa323', poolAbi, baseProvider);
		return pool.getDepositsOnTheWay();
	};
	const getChildPoolsCcipLogs = async ccipLines => {
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
		return await Promise.all(promises);
	};
	const getCompletedConceroIdsByLogs = (logs, ccipLines) => {
		if (!logs?.length) return [];
		const conceroIds = [];
		for (const log of logs) {
			const ccipMessageId = log[0].topics[1];
			const ccipLine = ccipLines.find(line => line.ccipMessageId.toLowerCase() === ccipMessageId.toLowerCase());
			conceroIds.push(ccipLine.conceroId);
		}
		return conceroIds;
	};
	const packResult = (_totalBalance, _conceroIds) => {
		const result = new Uint8Array(32 + conceroIds.length + 1);
		const encodedTotalBalance = Functions.encodeUint256(_totalBalance);
		result.set(encodedTotalBalance, 0);
		console.log(encodedTotalBalance);
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
		const ccipLines = [];
		for (let i = 0; i < 250; i++) {
			ccipLines.push({
				conceroId: '0x' + i.toString(16),
				chainSelector: 6433500567565415381n,
				ccipMessageId: '0x0fbe88fb5f2c85d0e42b031bcf44ddfb4c965a91a1fedcd796e86c13853e937d',
			});
		}
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
