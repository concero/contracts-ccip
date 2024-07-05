async function f() {
	const chainSelectors = {
		[`0x${BigInt('14767482510784806043').toString(16)}`]: {
			urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa869',
			usdcAddress: '0x5425890298aed601595a70ab815c96711a31bc65',
			poolAddress: '',
		},
		[`0x${BigInt('16015286601757825753').toString(16)}`]: {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
				'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
			],
			chainId: '0xaa36a7',
			usdcAddress: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
			poolAddress: '',
		},
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0x52536BDa65E4a5a43411aeFa968e166dE782abcB',
		},
		[`0x${BigInt('5224473277236331295').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '0x5fd84259d66Cd46123540766Be93DFE6D43130D7',
			poolAddress: '0xCE80F13941446FbA1E7dFB49f1454044081Ee7Ae',
		},
		[`0x${BigInt('16281711391670634445').toString(16)}`]: {
			urls: [
				`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon-amoy.blockpi.network/v1/rpc/public',
				'https://polygon-amoy-bor-rpc.publicnode.com',
			],
			chainId: '0x13882',
			usdcAddress: '0x41e94eb019c0762f9bfcf9fb1e58725bfb0e7582',
			poolAddress: '',
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
