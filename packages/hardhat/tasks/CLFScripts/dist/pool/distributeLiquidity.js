const ethers = await import('npm:ethers');
try {
	const [_, __, ___, newPoolChainSelector] = bytesArgs;
	const chainSelectors = {
		[`0x${BigInt('4949039107694359620').toString(16)}`]: {
			urls: [
				`https://arbitrum.infura.io/v3/${secrets.INFURA_API_KEY}`,
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
	};
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = [
		'function s_loansInUse() external view returns (uint256)',
		'function distributeLiquidity(uint64, uint256) external',
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
	const getPoolsBalances = async () => {
		const getBalancePromises = [];
		for (const chain in chainSelectors) {
			if (chain === newPoolChainSelector) continue;
			const url = chainSelectors[chain].urls[Math.floor(Math.random() * chainSelectors[chain].urls.length)];
			const provider = new FunctionsJsonRpcProvider(url);
			const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
			const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
			getBalancePromises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
			getBalancePromises.push(pool.s_loansInUse());
		}
		const results = await Promise.all(getBalancePromises);
		const balances = {};
		const chainSelectorsArr = Object.keys(chainSelectors);
		for (let i = 0, k = 0; i < results.length; i += 2, k++) {
			balances[chainSelectorsArr[k]] = results[i] + results[i + 1];
		}
		return balances;
	};
	const poolsBalances = await getPoolsBalances();
	console.log(poolsBalances);
	return Functions.encodeUint256(1n);
} catch (e) {
	const {message, code} = e;
	if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low') || message?.includes('already known')) {
		return Functions.encodeUint256(1n);
	}
	throw e;
}
