async function f() {
	const chainSelectors = {
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '${USDC_ARBITRUM_SEPOLIA}',
			poolAddress: '${CHILD_POOL_PROXY_ARBITRUM_SEPOLIA}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '${USDC_OPTIMISM_SEPOLIA}',
			poolAddress: '${CHILD_POOL_PROXY_OPTIMISM_SEPOLIA}',
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
			urls: [
				`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://avalanche-fuji-c-chain-rpc.publicnode.com',
				'https://avalanche-fuji.blockpi.network/v1/rpc/public',
			],
			chainId: '0xa869',
			usdcAddress: '${USDC_FUJI}',
			poolAddress: '${CHILD_POOL_PROXY_FUJI}',
		},

		// mainnets

		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM}').toString(16)}`]: {
		// 	urls: [
		// 		`https://arbitrum-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
		// 		'https://arbitrum.blockpi.network/v1/rpc/public',
		// 		'https://arbitrum-rpc.publicnode.com',
		// 	],
		// 	chainId: '0xa4b1',
		// 	usdcAddress: '${USDC_ARBITRUM}',
		// 	poolAddress: '${CHILD_POOL_PROXY_ARBITRUM}',
		// },
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON}').toString(16)}`]: {
		// 	urls: [
		// 		`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
		// 		'https://polygon.blockpi.network/v1/rpc/public',
		// 		'https://polygon-bor-rpc.publicnode.com',
		// 	],
		// 	chainId: '0x89',
		// 	usdcAddress: '${USDC_POLYGON}',
		// 	poolAddress: '${CHILD_POOL_PROXY_POLYGON}',
		// },
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_AVALANCHE}').toString(16)}`]: {
		// 	urls: [
		// 		`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
		// 		'https://avalanche.blockpi.network/v1/rpc/public',
		// 		'https://avalanche-c-chain-rpc.publicnode.com',
		// 	],
		// 	chainId: '0xa86a',
		// 	usdcAddress: '${USDC_AVALANCHE}',
		// 	poolAddress: '${CHILD_POOL_PROXY_AVALANCHE}',
		// },
	};
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = ['function s_loansInUse() external view returns (uint256)'];

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

	const promises = [];
	let totalBalance = 0n;

	for (const chain in chainSelectors) {
		const url = chainSelectors[chain].urls[Math.floor(Math.random() * chainSelectors[chain].urls.length)];
		const provider = new FunctionsJsonRpcProvider(url);
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		promises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
		promises.push(pool.s_loansInUse());
	}

	const results = await Promise.all(promises);

	for (let i = 0; i < results.length; i += 2) {
		totalBalance += BigInt(results[i]) + BigInt(results[i + 1]);
	}

	return Functions.encodeUint256(totalBalance);
}
f();
