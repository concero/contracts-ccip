/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/

try {
	const ethers = await import('npm:ethers@6.10.0');
	const [
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
		'${CL_CCIP_CHAIN_SELECTOR_FUJI}': {
			url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
		},
		'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
			url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		},
		'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
			url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		},
		'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
			url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
		},
		'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
			url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
		},
	};
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
			if (payload.method === 'eth_estimateGas') {
				return [{jsonrpc: '2.0', id: payload.id, result: '0x1e8480'}];
			}
			if (
				(payload.method === 'eth_chainId' && payload.id === 4) ||
				(payload.method === 'eth_chainId' && payload.id === 5)
			) {
				return [res];
			}
			return res;
		}
	}
	const abi = ['function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external'];
	const provider = new FunctionsJsonRpcProvider(chainSelectors[dstChainSelector].url);
	const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
	const signer = wallet.connect(provider);
	const contract = new ethers.Contract(dstContractAddress, abi, signer);
	const tx = await contract.addUnconfirmedTX(
		ccipMessageId,
		sender,
		recipient,
		amount,
		srcChainSelector,
		token,
		blockNumber,
	);
	return Functions.encodeString(tx.hash);
} catch (error) {
	console.error(error);
	throw new Error(error.message.slice(0, 255));
}
