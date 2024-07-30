(async () => {
	const chainSelectors = {
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0xb27c9076f5459AFfc3D17b7e830638a885349114',
		},
		[`0x${BigInt('14767482510784806043').toString(16)}`]: {
			urls: [
				`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
			],
			chainId: '0xa869',
			usdcAddress: '0x5425890298aed601595a70ab815c96711a31bc65',
			poolAddress: '0x931Ac651D313f7784B2598834cebF594120b9DB3',
		},
		[`0x${BigInt('10344971235874465080').toString(16)}`]: {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
			],
			chainId: '0x14a34',
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
		const urls = chainSelectors[_chainSelector].urls;
		const url = urls[Math.floor(Math.random() * urls.length)];
		return new FunctionsJsonRpcProvider(url);
	};
	const baseProvider = getProviderByChainSelector(baseChainSelector);
	const getBaseDepositsOneTheWay = () => {
		const pool = new ethers.Contract('0x973c3aA8879926022EA871cfa533d148e5eCea1c', poolAbi, baseProvider);
		return pool.getDepositsOnTheWay();
	};
	const getChildPoolsCcipLogs = async ccipLines => {
		const ethersId = ethers.id('ConceroChildPool_CCIPReceived(bytes32,uint64,address,address,uint256)');
		const promises = [];
		for (const line of ccipLines) {
			const hexChainSelector = `0x${BigInt(line.chainSelector).toString(16)}`.toLowerCase();
			if (!chainSelectors[hexChainSelector]) continue;
			const provider = getProviderByChainSelector(hexChainSelector);
			promises.push(
				provider.getLogs({
					address: chainSelectors[hexChainSelector].poolAddress,
					topics: [ethersId, line.ccipMessageId],
					fromBlock: 0,
					toBlock: 'latest',
				}),
			);
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
		if (chain === baseChainSelector) continue;
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
			} catch (e) {}
		}
	}
	return packResult(totalBalance, conceroIds);
})();
