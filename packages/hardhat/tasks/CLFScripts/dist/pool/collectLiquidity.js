async function f() {
	try {
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
				poolAddress: '0x390661e47a0013889b2bA26d1B7d01fdCD8F0bcC',
			},
		};
		class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
			constructor(url) {
				super(url);
				this.url = url;
			}
			async _send(payload) {
				if (payload.method === 'eth_estimateGas') {
					return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}];
				}
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
		const promises = [];
		for (const chainSelector in chainSelectors) {
			const url =
				chainSelectors[chainSelector].urls[Math.floor(Math.random() * chainSelectors[chainSelector].urls.length)];
			const provider = new FunctionsJsonRpcProvider(url);
			const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
			const signer = wallet.connect(provider);
			const poolContract = new ethers.Contract(chainSelectors[chainSelector].poolAddress, poolAbi, signer);
			promises.push(poolContract.ccipSendToPool(liquidityProvider, tokenAmount));
		}
		await Promise.all(promises);
		return Functions.encodeUint256(1n);
	} catch (e) {
		const {message, code} = e;
		if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low') || message?.includes('already known')) {
			return Functions.encodeUint256(1n);
		}
		throw e;
	}
}
f();
