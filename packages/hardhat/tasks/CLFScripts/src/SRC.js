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
			chainId: '0xa869',
		},
		'${CL_CCIP_CHAIN_SELECTOR_SEPOLIA}': {
			url: `https://sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			chainId: '0xaa36a7',
		},
		'${CL_CCIP_CHAIN_SELECTOR_ARBITRUM_SEPOLIA}': {
			url: `https://arbitrum-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			chainId: '0x66eee',
		},
		'${CL_CCIP_CHAIN_SELECTOR_BASE_SEPOLIA}': {
			url: `https://base-sepolia.g.alchemy.com/v2/${secrets.ALCHEMY_API_KEY}`,
			chainId: '0x14a34',
		},
		'${CL_CCIP_CHAIN_SELECTOR_OPTIMISM_SEPOLIA}': {
			url: `https://optimism-sepolia.infura.io/v3/${secrets.INFURA_API_KEY}`,
			chainId: '0xaa37dc',
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
			if (payload.method === 'eth_chainId') {
				return [{jsonrpc: '2.0', id: payload.id, result: chainSelectors[dstChainSelector].chainId}];
			}
			let resp = await fetch(this.url, {
				method: 'POST',
				headers: {'Content-Type': 'application/json'},
				body: JSON.stringify(payload),
			});
			return resp.json();
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
	if (
		(error.code === 'UNKNOWN_ERROR' && error.message.includes('already known')) ||
		error.message.includes('replacement fee too low') ||
		error.message.includes('nonce has already been used')
	) {
		return Functions.encodeString('already known');
	}
	throw new Error(error.message.slice(0, 255));
}
