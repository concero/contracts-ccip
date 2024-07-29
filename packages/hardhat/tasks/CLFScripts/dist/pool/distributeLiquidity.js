(async () => {
	try {
		const [_, __, ___, newPoolChainSelector, distributeLiquidityRequestId, distributionType] = bytesArgs;
		const chainSelectors = {
			[`0x${BigInt('3478487238524512106').toString(16)}`]: {
				urls: [
					`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
					'https://arbitrum-sepolia-rpc.publicnode.com',
				],
				chainId: '0x66eee',
				usdcAddress: '0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d',
				poolAddress: '0x3c69809aC32618F4E8842729b63A4679d1971aA5',
			},
			[`0x${BigInt('5224473277236331295').toString(16)}`]: {
				urls: [
					`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://optimism-sepolia.blockpi.network/v1/rpc/public',
					'https://optimism-sepolia-rpc.publicnode.com',
				],
				chainId: '0xaa37dc',
				usdcAddress: '0x5fd84259d66Cd46123540766Be93DFE6D43130D7',
				poolAddress: '0xb0260E0A79cb31a196bB798005ff7b20E1E79E2F',
			},
			[`0x${BigInt('14767482510784806043').toString(16)}`]: {
				urls: [
					`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
					'https://avalanche-fuji-c-chain-rpc.publicnode.com',
					'https://avalanche-fuji.blockpi.network/v1/rpc/public',
				],
				chainId: '0xa869',
				usdcAddress: '0x5425890298aed601595a70ab815c96711a31bc65',
				poolAddress: '0x869a621003BC70fceA9d12267a3B80E49cCbEFE3',
			},
		};
		const erc20Abi = ['function balanceOf(address) external view returns (uint256)'];
		const poolAbi = [
			'function s_loansInUse() external view returns (uint256)',
			'function distributeLiquidity(uint64, uint256, bytes32) external',
			'function liquidatePool(bytes32) external',
		];
		const chainSelectorsArr = Object.keys(chainSelectors);
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
		const getProviderByChainSelector = _chainSelector => {
			const url =
				chainSelectors[_chainSelector].urls[Math.floor(Math.random() * chainSelectors[_chainSelector].urls.length)];
			return new FunctionsJsonRpcProvider(url);
		};
		const getSignerByChainSelector = _chainSelector => {
			const provider = getProviderByChainSelector(_chainSelector);
			const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
			return wallet.connect(provider);
		};
		if (distributionType === '0x0') {
			const getPoolsBalances = async () => {
				const getBalancePromises = [];
				for (const chain in chainSelectors) {
					if (chain === newPoolChainSelector) continue;
					const provider = getProviderByChainSelector(chain);
					const erc20 = new ethers.Contract(chainSelectors[chain].usdcAddress, erc20Abi, provider);
					const pool = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, provider);
					getBalancePromises.push(erc20.balanceOf(chainSelectors[chain].poolAddress));
					getBalancePromises.push(pool.s_loansInUse());
				}
				const results = await Promise.all(getBalancePromises);
				const balances = {};
				for (let i = 0, k = 0; i < results.length; i += 2, k++) {
					balances[chainSelectorsArr[k]] = results[i] + results[i + 1];
				}
				return balances;
			};
			const poolsBalances = await getPoolsBalances();
			const poolsTotalBalance = chainSelectorsArr.reduce((acc, pool) => acc + poolsBalances[pool], 0n);
			const newPoolsCount = Object.keys(chainSelectors).length + 1;
			const newPoolBalance = poolsTotalBalance / BigInt(newPoolsCount);
			const distributeAmountPromises = [];
			for (const chain in chainSelectors) {
				if (chain === newPoolChainSelector) continue;
				const signer = getSignerByChainSelector(chain);
				const poolContract = new ethers.Contract(chainSelectors[chain].poolAddress, poolAbi, signer);
				const amountToDistribute = poolsBalances[chain] - newPoolBalance;
				distributeAmountPromises.push(
					poolContract.distributeLiquidity(newPoolChainSelector, amountToDistribute, distributeLiquidityRequestId),
				);
			}
			await Promise.all(distributeAmountPromises);
			return Functions.encodeUint256(1n);
		} else if (distributionType === '0x1') {
			const signer = getSignerByChainSelector(newPoolChainSelector);
			const poolContract = new ethers.Contract(chainSelectors[newPoolChainSelector].poolAddress, poolAbi, signer);
			await poolContract.liquidatePool(distributeLiquidityRequestId);
			return Functions.encodeUint256(1n);
		}
		throw new Error('Invalid distribution type');
	} catch (e) {
		const {message, code} = e;
		if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low') || message?.includes('already known')) {
			return Functions.encodeUint256(1n);
		}
		throw e;
	}
})();