async function f() {
	const [
		_,
		__,
		___,
		dstContractAddress,
		ccipMessageId,
		sender,
		recipient,
		amount,
		srcChainSelector,
		dstChainSelector,
		token,
		blockNumber,
		dstSwapData,
	] = bytesArgs;
	const chainSelectors = {
		[`0x${BigInt('14767482510784806043').toString(16)}`]: {
			urls: [`https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`],
			chainId: '0xa869',
			priceFeed: {
				linkUsd: '',
				usdcUsd: '',
				nativeUsd: '',
				linkNative: '',
			},
		},
		[`0x${BigInt('16015286601757825753').toString(16)}`]: {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
				'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
			],
			chainId: '0xaa36a7',
			priceFeed: {
				linkUsd: '',
				usdcUsd: '',
				nativeUsd: '',
				linkNative: '',
			},
		},
		[`0x${BigInt('3478487238524512106').toString(16)}`]: {
			urls: [
				`https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum-sepolia.blockpi.network/v1/rpc/public',
				'https://arbitrum-sepolia-rpc.publicnode.com',
			],
			chainId: '0x66eee',
			priceFeed: {
				linkUsd: '0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298',
				usdcUsd: '0x0153002d20B96532C639313c2d54c3dA09109309',
				nativeUsd: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
				linkNative: '0x3ec8593F930EA45ea58c968260e6e9FF53FC934f',
			},
		},
		[`0x${BigInt('10344971235874465080').toString(16)}`]: {
			urls: [
				`https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
				'https://base-sepolia.blockpi.network/v1/rpc/public',
				'https://base-sepolia-rpc.publicnode.com',
			],
			chainId: '0x14a34',
			priceFeed: {
				linkUsd: '0xb113F5A928BCfF189C998ab20d753a47F9dE5A61',
				usdcUsd: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
				nativeUsd: '0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1',
				linkNative: '0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69',
			},
		},
		[`0x${BigInt('5224473277236331295').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			priceFeed: {
				linkUsd: '0x53f91dA33120F44893CB896b12a83551DEDb31c6',
				usdcUsd: '0x6e44e50E3cc14DD16e01C590DC1d7020cb36eD4C',
				nativeUsd: '0x61Ec26aA57019C486B10502285c5A3D4A4750AD7',
				linkNative: '0x98EeB02BC20c5e7079983e8F0D0D839dFc8F74fA',
			},
		},
	};
	const UINT256_BYTES_LENGTH = 32;
	const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
	const getPercent = (value, percent) => (BigInt(value) * BigInt(percent)) / 100n;
	const getPriceRates = async (provider, chainSelector) => {
		const priceFeedsAbi = ['function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80)'];
		const linkUsdContract = new ethers.Contract(chainSelectors[chainSelector].priceFeed.linkUsd, priceFeedsAbi, provider);
		const usdcUsdContract = new ethers.Contract(chainSelectors[chainSelector].priceFeed.usdcUsd, priceFeedsAbi, provider);
		const nativeUsdContract = new ethers.Contract(
			chainSelectors[chainSelector].priceFeed.nativeUsd,
			priceFeedsAbi,
			provider,
		);
		const linkNativeContract = new ethers.Contract(
			chainSelectors[chainSelector].priceFeed.linkNative,
			priceFeedsAbi,
			provider,
		);
		const [linkUsd, usdcUsd, nativeUsd, linkNative] = await Promise.all([
			linkUsdContract.latestRoundData(),
			usdcUsdContract.latestRoundData(),
			nativeUsdContract.latestRoundData(),
			linkNativeContract.latestRoundData(),
		]);
		return {
			linkUsdc: linkUsd[1] > 0n ? (linkUsd[1] * 10n ** 18n) / usdcUsd[1] : 0n,
			nativeUsdc: nativeUsd[1] > 0n ? (nativeUsd[1] * 10n ** 18n) / usdcUsd[1] : 0n,
			linkNative: linkNative[1] > 0 ? linkNative[1] : 0n,
		};
	};
	const constructResult = items => {
		const encodedValues = items.map(value => Functions.encodeUint256(BigInt(value)));
		const totalLength = encodedValues.length * UINT256_BYTES_LENGTH;
		const result = new Uint8Array(totalLength);
		let offset = 0;
		for (const encoded of encodedValues) {
			result.set(encoded, offset);
			offset += UINT256_BYTES_LENGTH;
		}
		return result;
	};
	let nonce = 0;
	let retries = 0;
	let gasPrice;
	let maxPriorityFeePerGas;
	const sendTransaction = async (contract, signer, txOptions) => {
		try {
			if ((await contract.s_transactions(ccipMessageId))[1] !== '0x0000000000000000000000000000000000000000') return;
			await contract.addUnconfirmedTX(
				ccipMessageId,
				sender,
				recipient,
				amount,
				srcChainSelector,
				token,
				blockNumber,
				dstSwapData,
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
					const _chainId = chainSelectors[srcChainSelector].urls.includes(this.url)
						? chainSelectors[srcChainSelector].chainId
						: chainSelectors[dstChainSelector].chainId;
					return [{jsonrpc: '2.0', id: payload.id, result: _chainId}];
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
			'function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256, bytes) external',
			'function s_transactions(bytes32) view returns (bytes32, address, address, uint256, uint8, uint64, bool)',
		];
		const contract = new ethers.Contract(dstContractAddress, abi, signer);
		const [feeData, nonce] = await Promise.all([provider.getFeeData(), provider.getTransactionCount(wallet.address)]);
		gasPrice = feeData.gasPrice;
		maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
		await sendTransaction(contract, signer, {
			nonce,
			maxPriorityFeePerGas: maxPriorityFeePerGas + getPercent(maxPriorityFeePerGas, 10),
			maxFeePerGas: gasPrice + getPercent(gasPrice, 10),
		});
		const srcUrl =
			chainSelectors[srcChainSelector].urls[Math.floor(Math.random() * chainSelectors[srcChainSelector].urls.length)];
		const srcChainProvider = new FunctionsJsonRpcProvider(srcUrl);
		const [dstFeeData, srcPriceFeeds] = await Promise.all([
			srcChainProvider.getFeeData(),
			getPriceRates(srcChainProvider, srcChainSelector),
		]);
		return constructResult([
			dstFeeData.gasPrice,
			gasPrice,
			dstChainSelector,
			srcPriceFeeds.linkUsdc,
			srcPriceFeeds.nativeUsdc,
			srcPriceFeeds.linkNative,
		]);
	} catch (error) {
		const {message} = error;
		if (message?.includes('Exceeded maximum of 20 HTTP queries')) {
			return new Uint8Array(1);
		} else {
			throw new Error(message?.slice(0, 255));
		}
	}
}
f();
