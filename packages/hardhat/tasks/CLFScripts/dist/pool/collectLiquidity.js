(async () => {
	try {
		const [_, __, liquidityProvider, liquidityRequestedFromEachPool, withdrawalId] = bytesArgs;
		const chainSelectors = {
			[`0x${BigInt('3478487238524512106').toString(16)}`]: {
				urls: [
					`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
					'https://arbitrum-sepolia-rpc.publicnode.com',
				],
				chainId: '0x66eee',
				usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
				poolAddress: '0xb27c9076f5459AFfc3D17b7e830638a885349114',
			},
			[`0x${BigInt('14767482510784806043').toString(16)}`]: {
				urls: [
					`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://avalanche-fuji-c-chain-rpc.publicnode.com',
					'https://avalanche-fuji.blockpi.network/v1/rpc/public',
				],
				chainId: '0xa869',
				usdcAddress: '0x5425890298aed601595a70ab815c96711a31bc65',
				poolAddress: '0x931Ac651D313f7784B2598834cebF594120b9DB3',
			},
		};
		const getChainIdByUrl = url => {
			for (const chain in chainSelectors) {
				if (chainSelectors[chain].urls.includes(url)) return chainSelectors[chain].chainId;
			}
			return null;
		};
		const baseChainSelector = `0x${BigInt('10344971235874465080').toString(16)}`;
		class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
			constructor(url) {
				super(url);
				this.url = url;
			}
			async _send(payload) {
				if (payload.method === 'eth_estimateGas') {
					return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}];
				}
				if (payload.method === 'eth_chainId') {
					const _chainId = getChainIdByUrl(this.url);
					return [{jsonrpc: '2.0', id: payload.id, result: _chainId}];
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
		const poolAbi = ['function ccipSendToPool(uint64, address, uint256, bytes32) external'];
		const promises = [];
		for (const chainSelector in chainSelectors) {
			const url =
				chainSelectors[chainSelector].urls[Math.floor(Math.random() * chainSelectors[chainSelector].urls.length)];
			const provider = new FunctionsJsonRpcProvider(url);
			const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
			const signer = wallet.connect(provider);
			const poolContract = new ethers.Contract(chainSelectors[chainSelector].poolAddress, poolAbi, signer);
			promises.push(
				poolContract.ccipSendToPool(baseChainSelector, liquidityProvider, liquidityRequestedFromEachPool, withdrawalId),
			);
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
})();
