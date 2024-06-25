(async () => {
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
			nativeCurrency: 'avax',
			priceFeed: {
				linkUsd: '',
				usdcUsd: '',
				nativeUsd: '',
				linkNative: '',
				maticUsd: '',
				ethUsd: '',
			},
		},
		[`0x${BigInt('16015286601757825753').toString(16)}`]: {
			urls: [
				`https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://ethereum-sepolia-rpc.publicnode.com',
				'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
			],
			chainId: '0xaa36a7',
			nativeCurrency: 'eth',
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
			nativeCurrency: 'eth',
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
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '0xb113F5A928BCfF189C998ab20d753a47F9dE5A61',
				usdcUsd: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165',
				nativeUsd: '0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1',
				linkNative: '0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69',
				maticUsd: '0x12129aAC52D6B0f0125677D4E1435633E61fD25f',
				avaxUsd: '0xE70f2D34Fd04046aaEC26a198A35dD8F2dF5cd92',
			},
		},
		[`0x${BigInt('5224473277236331295').toString(16)}`]: {
			urls: [
				`https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://optimism-sepolia.blockpi.network/v1/rpc/public',
				'https://optimism-sepolia-rpc.publicnode.com',
			],
			chainId: '0xaa37dc',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '0x53f91dA33120F44893CB896b12a83551DEDb31c6',
				usdcUsd: '0x6e44e50E3cc14DD16e01C590DC1d7020cb36eD4C',
				nativeUsd: '0x61Ec26aA57019C486B10502285c5A3D4A4750AD7',
				linkNative: '0x98EeB02BC20c5e7079983e8F0D0D839dFc8F74fA',
			},
		},
		[`0x${BigInt('16281711391670634445').toString(16)}`]: {
			urls: [
				`https://polygon-amoy.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon-amoy.blockpi.network/v1/rpc/public',
				'https://polygon-amoy-bor-rpc.publicnode.com',
			],
			chainId: '0x13882',
			nativeCurrency: 'matic',
			priceFeed: {
				linkUsd: '0xc2e2848e28B9fE430Ab44F55a8437a33802a219C',
				usdcUsd: '0x1b8739bB4CdF0089d07097A9Ae5Bd274b29C6F16',
				nativeUsd: '0x001382149eBa3441043c1c66972b4772963f5D43',
				linkNative: '0x408D97c89c141e60872C0835e18Dd1E670CD8781',
				ethUsd: '0xF0d50568e3A7e8259E16663972b11910F89BD8e7',
			},
		},
		[`0x${BigInt('15971525489660198786').toString(16)}`]: {
			urls: [
				'https://base.blockpi.network/v1/rpc/public',
				'https://base-rpc.publicnode.com',
			],
			chainId: '0x2105',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '0x17CAb8FE31E32f08326e5E27412894e49B0f9D65',
				usdcUsd: '0x7e860098F58bBFC8648a4311b374B1D669a2bc6B',
				nativeUsd: '0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70',
				linkNative: '0xc5E65227fe3385B88468F9A01600017cDC9F3A12',
				maticUsd: '0x12129aAC52D6B0f0125677D4E1435633E61fD25f',
				avaxUsd: '0xE70f2D34Fd04046aaEC26a198A35dD8F2dF5cd92',
			},
		},
		[`0x${BigInt('4949039107694359620').toString(16)}`]: {
			urls: [
				`https://arbitrum.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://arbitrum.blockpi.network/v1/rpc/public',
				'https://arbitrum-rpc.publicnode.com',
			],
			chainId: '0xa4b1',
			nativeCurrency: 'eth',
			priceFeed: {
				linkUsd: '0x86E53CF1B870786351Da77A57575e79CB55812CB',
				usdcUsd: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3',
				nativeUsd: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
				linkNative: '0xb7c8Fb1dB45007F98A68Da0588e1AA524C317f27',
			},
		},
		[`0x${BigInt('4051577828743386545').toString(16)}`]: {
			urls: [
				`https://polygon-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://polygon.blockpi.network/v1/rpc/public',
				'https://polygon-bor-rpc.publicnode.com',
			],
			chainId: '0x89',
			nativeCurrency: 'matic',
			priceFeed: {
				linkUsd: '0xd9FFdb71EbE7496cC440152d43986Aae0AB76665',
				usdcUsd: '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7',
				nativeUsd: '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0',
				linkNative: '0x5787BefDc0ECd210Dfa948264631CD53E68F7802',
				ethUsd: '0xF9680D99D6C9589e2a93a78A04A279e509205945',
				avaxUsd: '0xe01eA2fbd8D76ee323FbEd03eB9a8625EC981A10',
			},
		},
		[`0x${BigInt('6433500567565415381').toString(16)}`]: {
			urls: [
				`https://avalanche-mainnet.infura.io/v3/${secrets.INFURA_API_KEY}`,
				'https://avalanche.blockpi.network/v1/rpc/public',
				'https://avalanche-c-chain-rpc.publicnode.com',
			],
			chainId: '0xa86a',
			nativeCurrency: 'avax',
			priceFeed: {
				linkUsd: '0x49ccd9ca821EfEab2b98c60dC60F518E765EDe9a',
				usdcUsd: '0xF096872672F44d6EBA71458D74fe67F9a77a23B9',
				nativeUsd: '0x0A77230d17318075983913bC2145DB16C7366156',
				linkNative: '0x1b8a25F73c9420dD507406C3A3816A276b62f56a',
				ethUsd: '0x976B3D034E162d8bD72D6b9C989d545b839003b0',
				maticUsd: '0x1db18D41E4AD2403d9f52b5624031a2D9932Fd73',
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
		const promises = [
			linkUsdContract.latestRoundData(),
			usdcUsdContract.latestRoundData(),
			nativeUsdContract.latestRoundData(),
			linkNativeContract.latestRoundData(),
		];
		const promiseUndefined = async () => {
			return new Promise(resolve => {
				resolve(undefined);
			});
		};
		if (chainSelectors[chainSelector].priceFeed.maticUsd) {
			const maticUsdContract = new ethers.Contract(
				chainSelectors[chainSelector].priceFeed.maticUsd,
				priceFeedsAbi,
				provider,
			);
			promises.push(maticUsdContract.latestRoundData());
		} else {
			promises.push(promiseUndefined());
		}
		if (chainSelectors[chainSelector].priceFeed.ethUsd) {
			const ethUsdContract = new ethers.Contract(chainSelectors[chainSelector].priceFeed.ethUsd, priceFeedsAbi, provider);
			promises.push(ethUsdContract.latestRoundData());
		} else {
			promises.push(promiseUndefined());
		}
		if (chainSelectors[chainSelector].priceFeed.avaxUsd) {
			const avaxUsdContract = new ethers.Contract(
				chainSelectors[chainSelector].priceFeed.avaxUsd,
				priceFeedsAbi,
				provider,
			);
			promises.push(avaxUsdContract.latestRoundData());
		} else {
			promises.push(promiseUndefined());
		}
		const [linkUsd, usdcUsd, nativeUsd, linkNative, maticUsd, ethUsd, avaxUsd] = await Promise.all(promises);
		return {
			linkUsdc: linkUsd[1] > 0n ? (linkUsd[1] * 10n ** 18n) / usdcUsd[1] : 0n,
			nativeUsdc: nativeUsd[1] > 0n ? (nativeUsd[1] * 10n ** 18n) / usdcUsd[1] : 0n,
			linkNative: linkNative[1] > 0 ? linkNative[1] : 0n,
			nativeUsd: nativeUsd[1] > 0 ? nativeUsd[1] : 0n,
			maticUsd: maticUsd ? maticUsd[1] : undefined,
			ethUsd: ethUsd ? ethUsd[1] : undefined,
			avaxUsd: avaxUsd ? avaxUsd[1] : undefined,
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
	const getDstGasPriceInSrcCurrency = (_gasPrice, srcPriceFeeds) => {
		const getGasPriceByPriceFeeds = (nativeUsdPriceFeed, dstAssetUsdPriceFeed, __gasPrice) => {
			if (dstAssetUsdPriceFeed === undefined) return 0n;
			const srcNativeDstNativeRate = (nativeUsdPriceFeed * 10n ** 10n) / dstAssetUsdPriceFeed;
			return (__gasPrice * srcNativeDstNativeRate) / 10n ** 18n;
		};
		if (chainSelectors[srcChainSelector].nativeCurrency === 'eth') {
			if (chainSelectors[dstChainSelector].nativeCurrency === 'matic') {
				return getGasPriceByPriceFeeds(srcPriceFeeds.nativeUsd, srcPriceFeeds.maticUsd, _gasPrice);
			} else if (chainSelectors[dstChainSelector].nativeCurrency === 'avax') {
				return getGasPriceByPriceFeeds(srcPriceFeeds.nativeUsd, srcPriceFeeds.avaxUsd, _gasPrice);
			}
		}
		return _gasPrice;
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
		const [srcFeeData, srcPriceFeeds] = await Promise.all([
			srcChainProvider.getFeeData(),
			getPriceRates(srcChainProvider, srcChainSelector),
		]);
		const dstGasPriceInSrcCurrency = getDstGasPriceInSrcCurrency(gasPrice, srcPriceFeeds);
		return constructResult([
			dstGasPriceInSrcCurrency,
			srcFeeData.gasPrice,
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
})();
