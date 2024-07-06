async function f() {
	const [_, __, liquidityProvider, tokenAmount] = bytesArgs;
	const chainSelectors = {
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
			poolAddress: '0x869a621003BC70fceA9d12267a3B80E49cCbEFE3',
		},
		[`0x${BigInt('5224473277236331295').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			usdcAddress: '0x5fd84259d66Cd46123540766Be93DFE6D43130D7',
			poolAddress: '0xE2E94C32beeB98F1b4D96F0E30a5a92af8f09108',
		},
	};
	const MASTER_POOL_CHAIN_SELECTOR = `0x${BigInt('10344971235874465080').toString(16)}`;
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
	const poolAbi = ['function ccipSendToPool(address, uint256) external returns (bytes32 messageId)'];
	for (const chainSelector in chainSelectors) {
		if (chainSelector === MASTER_POOL_CHAIN_SELECTOR) continue;
		const url = chainSelectors[chainSelector].urls[Math.floor(Math.random() * chainSelectors[chainSelector].urls.length)];
		const provider = new FunctionsJsonRpcProvider(url);
		const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
		const signer = wallet.connect(provider);
		const poolContract = new ethers.Contract(chainSelectors[chainSelector].poolAddress, poolAbi, signer);
		await poolContract.ccipSendToPool(liquidityProvider, tokenAmount);
		return Functions.encodeUint256(1n);
	}
}
f();
