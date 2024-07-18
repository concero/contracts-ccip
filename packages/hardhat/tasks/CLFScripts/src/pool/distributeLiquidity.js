const ethers = await import('npm:ethers');

// (async () => {
try {
	const [_, __, ___, newPoolChainSelector] = bytesArgs;
	const chainSelectors = {
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
			urls: [
				`https://arbitrum.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum.blockpi.network/v1/rpc/public',
				'https://arbitrum-rpc.publicnode.com',
			],
			chainId: '0xa4b1',
			usdcAddress: '${USDC_ARBITRUM}',
			poolAddress: '${CHILD_POOL_PROXY_ARBITRUM}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
			urls: [
				`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon.blockpi.network/v1/rpc/public',
				'https://polygon-bor-rpc.publicnode.com',
			],
			chainId: '0x89',
			usdcAddress: '${USDC_POLYGON}',
			poolAddress: '${CHILD_POOL_PROXY_POLYGON}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
			urls: [
				`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://avalanche.blockpi.network/v1/rpc/public',
				'https://avalanche-c-chain-rpc.publicnode.com',
			],
			chainId: '0xa86a',
			usdcAddress: '${USDC_AVALANCHE}',
			poolAddress: '${CHILD_POOL_PROXY_AVALANCHE}',
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

	// const poolsTotalBalance = poolsBalances.reduce((acc, pool) => acc + pool.balance, 0n);
	// const poolsCount = Object.keys(chainSelectors).length;
	// const newPoolBalance = poolsTotalBalance / BigInt(poolsCount);
	// const distributeAmountPromises = [];
	//
	// for (const chain in chainSelectors) {
	// 	if (chain === newPoolChainSelector) continue;
	// 	const url = chainSelectors[chain].urls[Math.floor(Math.random() * chainSelectors[chain].urls.length)];
	// 	const provider = new FunctionsJsonRpcProvider(url);
	// 	const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
	// 	const signer = wallet.connect(provider);
	// 	const poolContract = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, signer);
	// 	const amountToDistribute = poolsBalances[chain] - newPoolBalance;
	// 	console.log(amountToDistribute);
	// 	// distributeAmountPromises.push(poolContract.distributeLiquidity(newPoolChainSelector, amountToDistribute));
	// }

	// await Promise.all(distributeAmountPromises);

	return Functions.encodeUint256(1n);
} catch (e) {
	const {message, code} = e;
	if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low') || message?.includes('already known')) {
		return Functions.encodeUint256(1n);
	}
	throw e;
}
// })();
