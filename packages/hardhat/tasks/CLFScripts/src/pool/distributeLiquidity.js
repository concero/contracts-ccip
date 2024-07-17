(async () => {
	const chainSelectors = {
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
})();
