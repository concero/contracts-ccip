async function f() {
	try {
		const [_, __, liquidityProvider, tokenAmount] = bytesArgs;

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

			// mainnets

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
