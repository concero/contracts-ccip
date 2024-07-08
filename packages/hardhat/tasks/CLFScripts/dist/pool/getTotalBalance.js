async function f() {
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
		[`0x${BigInt('5224473277236331295').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '0x5fd84259d66Cd46123540766Be93DFE6D43130D7',
			poolAddress: '0xE7fB2fE07e73f7407b44040340d95d18aF8C28C9',
		},
		[`0x${BigInt('4949039107694359620').toString(16)}`]: {
			urls: [
				`https://arbitrum.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum.blockpi.network/v1/rpc/public',
				'https://arbitrum-rpc.publicnode.com',
			],
			chainId: '0xa4b1',
			usdcAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
			poolAddress: '0xbe43f1eAb754144b31B90Ee2D6E036b9AB3cC5B4',
		},
		[`0x${BigInt('4051577828743386545').toString(16)}`]: {
			urls: [
				`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon.blockpi.network/v1/rpc/public',
				'https://polygon-bor-rpc.publicnode.com',
			],
			chainId: '0x89',
			usdcAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
			poolAddress: '0xE7fB2fE07e73f7407b44040340d95d18aF8C28C9',
		},
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
		const fallBackProviders = chainSelectors[chain].urls.map(url => {
			return {
				provider: new FunctionsJsonRpcProvider(url),
				priority: Math.random(),
				stallTimeout: 2000,
				weight: 1,
			};
		});
		const provider = new ethers.FallbackProvider(fallBackProviders, null, {quorum: 1});
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
