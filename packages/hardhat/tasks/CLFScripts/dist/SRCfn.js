async function main() {
	const ethers = await import('npm:ethers@6.10.0');
	const [
		_,
		dstContractAddress,
		ccipMessageId,
		sender,
		recipient,
		amount,
		srcChainSelector,
		dstChainSelector,
		token,
		blockNumber,
	] = args;
	const chainSelectors = {
		'14767482510784806043': {
			urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa869',
		},
		'16015286601757825753': {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
				'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
			],
			chainId: '0xaa36a7',
		},
		'3478487238524512106': {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
		},
		'10344971235874465080': {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
				'https://base-sepolia.blockpi.network/v1/rpc/public',
				'https://base-sepolia-rpc.publicnode.com',
			],
			chainId: '0x14a34',
		},
		'5224473277236331295': {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
		},
	};
	const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
	let nonce = 0;
	let retries = 0;
	let gasPrice;
	const sendTransaction = async (contract, signer, txOptions) => {
		try {
			const transaction = await contract.transactions(ccipMessageId);
			if ((await contract.transactions(ccipMessageId))[1] !== '0x0000000000000000000000000000000000000000') return;
			await contract.addUnconfirmedTX(
				ccipMessageId,
				sender,
				recipient,
				amount,
				srcChainSelector,
				token,
				blockNumber,
				txOptions,
			);
		} catch (err) {
			const {message, code} = err;
			if (retries >= 5) {
				throw new Error('retries reached the limit ' + err.message?.slice(0, 200));
			} else if (code === 'NONCE_EXPIRED' || message?.includes('replacement fee too low')) {
				await sleep(1000 + Math.random() * 1500);
				retries++;
				await sendTransaction(contract, signer, {
					...txOptions,
					nonce: nonce++,
				});
			} else if (code === 'UNKNOWN_ERROR' && message?.includes('already known')) {
				return;
			} else {
				throw new Error(err.message?.slice(0, 255));
			}
		}
	};
	try {
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
					return [{jsonrpc: '2.0', id: payload.id, result: chainSelectors[dstChainSelector].chainId}];
				}
				let resp = await fetch(this.url, {
					method: 'POST',
					headers: {'Content-Type': 'application/json'},
					body: JSON.stringify(payload),
				});
				const res = await resp.json();
				if (res.length === undefined) {
					return [res];
				}
				return res;
			}
		}
		const dstUrl =
			chainSelectors[dstChainSelector].urls[Math.floor(Math.random() * chainSelectors[dstChainSelector].urls.length)];
		const provider = new FunctionsJsonRpcProvider(dstUrl);
		const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
		const signer = wallet.connect(provider);
		const abi = [
			'function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external',
			'function transactions(bytes32) view returns (bytes32, address, address, uint256, uint8, uint64, bool)',
		];
		const contract = new ethers.Contract(dstContractAddress, abi, signer);
		const feeData = await provider.getFeeData();
		nonce = await provider.getTransactionCount(wallet.address);
		gasPrice = feeData.gasPrice;
		await sendTransaction(contract, signer, {
			gasPrice,
			nonce,
		});
		const srcUrl =
			chainSelectors[srcChainSelector].urls[Math.floor(Math.random() * chainSelectors[srcChainSelector].urls.length)];
		const srcChainProvider = new FunctionsJsonRpcProvider(srcUrl);
		const srcGasPrice = Functions.encodeUint256(BigInt((await srcChainProvider.getFeeData()).gasPrice || 0));
		const dstGasPrice = Functions.encodeUint256(BigInt(gasPrice || 0));
		const encodedDstChainSelector = Functions.encodeUint256(BigInt(dstChainSelector || 0));
		const res = new Uint8Array(srcGasPrice.length + dstGasPrice.length + encodedDstChainSelector.length);
		res.set(srcGasPrice);
		res.set(dstGasPrice, srcGasPrice.length);
		res.set(encodedDstChainSelector, srcGasPrice.length + dstGasPrice.length);
		return res;
	} catch (error) {
		const {message} = error;
		if (message?.includes('Exceeded maximum of 20 HTTP queries')) {
			return new Uint8Array(1);
		} else {
			throw new Error(message?.slice(0, 255));
		}
	}
}
main();
