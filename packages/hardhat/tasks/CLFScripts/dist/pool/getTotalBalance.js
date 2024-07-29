const ethers = await import('npm:ethers@6.10.0');
return (async () => {
	const chainSelectors = {
		[`0x${BigInt('4949039107694359620').toString(16)}`]: {
			urls: [
				`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum.blockpi.network/v1/rpc/public',
				'https://arbitrum-rpc.publicnode.com',
			],
			chainId: '0xa4b1',
			usdcAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
			poolAddress: '0xb26f41a682601c70872B67667b30037f910E6c83',
		},
		[`0x${BigInt('4051577828743386545').toString(16)}`]: {
			urls: [
				`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon.blockpi.network/v1/rpc/public',
				'https://polygon-bor-rpc.publicnode.com',
			],
			chainId: '0x89',
			usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
			poolAddress: '0x1bb4233765838Ee69076845D10fa231c8cd500a3',
		},
		[`0x${BigInt('6433500567565415381').toString(16)}`]: {
			urls: [
				`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://avalanche.blockpi.network/v1/rpc/public',
				'https://avalanche-c-chain-rpc.publicnode.com',
			],
			chainId: '0xa86a',
			usdcAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
			poolAddress: '0x1bb4233765838Ee69076845D10fa231c8cd500a3',
		},
		[`0x${BigInt('15971525489660198786').toString(16)}`]: {
			urls: [
				'http://127.0.0.1:8545',
			],
			chainId: '0x2105',
			usdcAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
			poolAddress: '0x9d185A9aFb6ED0a0196EBCDfc22d1516ad02596A',
		},
	};
	const baseChainSelector = `0x${BigInt('15971525489660198786').toString(16)}`;
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
		const pool = new ethers.Contract('0x9d185A9aFb6ED0a0196EBCDfc22d1516ad02596A', poolAbi, baseProvider);
		return pool.getDepositsOnTheWay();
	};
	const getChildPoolsCcipLogs = async ccipLines => {
		const ethersId = ethers.id('ConceroParentPool_CCIPReceived(bytes32, uint64, address, address, uint256)');
		const promises = [];
		for (const line of ccipLines) {
			baseProvider.getLogs({
				address: '0x1bb4233765838Ee69076845D10fa231c8cd500a3',
				topics: [ethersId, line.ccipMessageId],
				fromBlock: latestBlockNumber - 1000n,
				toBlock: 'latest',
			});
		}
		const logs = await Promise.all(promises);
		console.log(logs);
	};
	let promises = [];
	let totalBalance = 0n;
	promises.push(getBaseDepositsOneTheWay());
	try {
		const results = await Promise.all(promises);
	} catch (error) {
		console.log(error);
	}
	for (let i = 0; i < results.length - 2; i += 2) {
		totalBalance += BigInt(results[i]) + BigInt(results[i + 1]);
	}
	const latestBlockNumber = BigInt(results[results.length - 1]);
	const depositsOnTheWay = results[results.length - 2];
	let conceroIdsOfCompletedDeposits = [];
	if (depositsOnTheWay.length) {
		const ccipLines = depositsOnTheWay.map(line => {
			const [conceroId, chainSelector, ccipMessageId] = line;
			return {conceroId, chainSelector, ccipMessageId};
		});
		if (ccipLines.length) {
			const logs = await getChildPoolsCcipLogs(ccipLines);
		}
	}
	return Functions.encodeUint256(totalBalance);
})();
