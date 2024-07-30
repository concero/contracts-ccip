(async () => {
	const chainSelectors = {
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0xbe43f1eAb754144b31B90Ee2D6E036b9AB3cC5B4',
		},
		[`0x${BigInt('14767482510784806043').toString(16)}`]: {
			urls: [
				`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://avalanche-fuji-c-chain-rpc.publicnode.com',
				'https://avalanche-fuji.blockpi.network/v1/rpc/public',
			],
			chainId: '0xa869',
			usdcAddress: '0x5425890298aed601595a70ab815c96711a31bc65',
			poolAddress: '',
		},
		[`0x${BigInt('10344971235874465080').toString(16)}`]: {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
				'https://base-sepolia.blockpi.network/v1/rpc/public',
				'https://base-sepolia-rpc.publicnode.com',
			],
			chainId: '0x14a34',
			nativeCurrency: 'eth',
			usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
			poolAddress: '0x973c3aA8879926022EA871cfa533d148e5eCea1c',
		},
	};
	const baseChainSelector = `0x${BigInt('10344971235874465080').toString(16)}`;
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = [
		'function s_loansInUse() external view returns (uint256)',
		'function getDepositsOnTheWay() external view returns (tuple(uint8, uint64, bytes32, uint256)[] memory)',
	];
	class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
		constructor(url) {
			super(url);
			this.url = url;
		}
		async _send(payload) {
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
		const url =
			chainSelectors[_chainSelector].urls[Math.floor(Math.random() * chainSelectors[_chainSelector].urls.length)];
		return new FunctionsJsonRpcProvider(url);
	};
	const baseProvider = getProviderByChainSelector(baseChainSelector);
	const getBaseDepositsOneTheWay = () => {
		const pool = new ethers.Contract('0x973c3aA8879926022EA871cfa533d148e5eCea1c', poolAbi, baseProvider);
		return pool.getDepositsOnTheWay();
	};
	const getChildPoolsCcipLogs = async (ccipLines, _latestBlockNumber) => {
		const ethersId = ethers.id('ConceroParentPool_CCIPReceived(bytes32, uint64, address, address, uint256)');
		const promises = [];
		for (const line of ccipLines) {
			const provider = getProviderByChainSelector(line.chainSelector);
			promises.push(
				provider.getLogs({
					address: chainSelectors[line.chainSelector].poolAddress,
					topics: [ethersId, line.ccipMessageId],
					fromBlock: _latestBlockNumber - 1000n,
					toBlock: _latestBlockNumber,
				}),
			);
		}
		return await Promise.all(promises);
	};
	const getCompletedConceroIdsByLogs = (logs, ccipLines) => {
		const conceroIds = [];
		for (const log of logs) {
			const ccipMessageId = log.topics[1];
			const ccipLine = ccipLines.find(line => line.ccipMessageId === ccipMessageId);
			conceroIds.push(ccipLine.conceroId);
		}
		return conceroIds;
	};
	const packResult = (_totalBalance, _conceroIds) => {
		const result = new Uint8Array(32 + conceroIds.length);
		const encodedTotalBalance = Functions.encodeUint256(_totalBalance);
		result.set(encodedTotalBalance, 0);
		if (_conceroIds.length) {
			for (let i = 0; i < _conceroIds.length; i++) {
				const encodedConceroId = new Uint8Array([Number(_conceroIds[i])]);
				result.set(encodedConceroId, 32 + i);
			}
		}
		return result;
	};
	let promises = [];
	let totalBalance = 0n;
	for (const chain in chainSelectors) {
		if (chain === baseChainSelector) continue;
		const provider = getProviderByChainSelector(chain);
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		promises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
		promises.push(pool.s_loansInUse());
	}
	promises.push(getBaseDepositsOneTheWay());
	promises.push(baseProvider.getBlockNumber());
	let results = [];
	results = await Promise.all(promises);
	for (let i = 0; i < results.length - 2; i += 2) {
		totalBalance += BigInt(results[i]) + BigInt(results[i + 1]);
	}
	const latestBlockNumber = BigInt(results[results.length - 1]);
	const depositsOnTheWay = results[results.length - 2];
	let conceroIds = [];
	if (depositsOnTheWay.length) {
		const ccipLines = depositsOnTheWay.map(line => {
			const [conceroId, chainSelector, ccipMessageId] = line;
			return {conceroId, chainSelector, ccipMessageId};
		});
		if (ccipLines.length) {
			const logs = await getChildPoolsCcipLogs(ccipLines, latestBlockNumber);
			conceroIds = getCompletedConceroIdsByLogs(logs, ccipLines);
		}
	}
	return packResult(totalBalance, conceroIds);
})();
