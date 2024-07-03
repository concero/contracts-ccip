async function f() {
	const ethers = await import('npm:ethers');

	const chainSelectors = {
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_FUJI}').toString(16)}`]: {
			urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa869',
			usdcAddress: '${USDC_FUJI}',
			poolAddress: '${CHILDPOOL_AVALANCHE_FUJI}', //CHANGE PARENTPOOL -> CHILDPOOL
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
				'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
			],
			chainId: '0xaa36a7',
			usdcAddress: '${USDC_SEPOLIA}',
			poolAddress: '${CHILDPOOL_SEPOLIA}', //CHANGE PARENTPOOL -> CHILDPOOL
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '${USDC_ARBITRUM_SEPOLIA}',
			poolAddress: '${CHILDPOOL_ARBITRUM_SEPOLIA}', //CHANGE PARENTPOOL -> CHILDPOOL
		},
		// [`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}').toString(16)}`]: {
		// 	urls: [
		// 		`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
		// 		'https://base-sepolia.blockpi.network/v1/rpc/public',
		// 		'https://base-sepolia-rpc.publicnode.com',
		// 	],
		// 	chainId: '0x14a34',
		// 	usdcAddress: '${USDC_BASE_SEPOLIA}',
		// 	poolAddress: '${PARENTPOOL_BASE_SEPOLIA}', //WE GET THIS ON-CHAIN
		// },
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '${USDC_OPTIMISM_SEPOLIA}',
			poolAddress: '${CHILDPOOL_OPTIMISM_SEPOLIA}', //CHANGE PARENTPOOL -> CHILDPOOL
		},
		[`0x${BigInt('${CL_CCIP_CHAIN_SELECTOR_POLYGON_AMOY}').toString(16)}`]: {
			urls: [
				`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon-amoy.blockpi.network/v1/rpc/public',
				'https://polygon-amoy-bor-rpc.publicnode.com',
			],
			chainId: '0x13882',
			usdcAddress: '${USDC_AMOY}',
			poolAddress: '${CHILDPOOL_POLYGON_AMOY}', //CHANGE PARENTPOOL -> CHILDPOOL
		},
	};
	const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
	const poolAbi = ['function s_commits() external view returns (uint256)'];

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

	let totalBalance = 0n;

	for (const chain in chainSelectors) {
		const url = chainSelectors[chain].urls[Math.floor(Math.random() * chainSelectors[chain].urls.length)];
		const provider = new FunctionsJsonRpcProvider(url);
		const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
		const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
		const [poolBalance, commits] = await Promise.all([
			erc20.balanceOf(chainSelectors[chain].poolAddress),
			pool.s_commits(),
		]);
		totalBalance += poolBalance + commits;
	}

	return Functions.encodeUint256(totalBalance);
}
f();
