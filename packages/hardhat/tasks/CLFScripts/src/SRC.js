/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */
// todo: convert var names to single characters
/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/

try {
	const ethers = await import('npm:ethers@6.10.0');
	const [
		contractAddress,
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
	const abi = ['function addUnconfirmedTX(bytes32, address, address, uint256, uint64, uint8, uint256) external'];
	const provider = new ethers.JsonRpcProvider(chainSelectors[dstChainSelector].url);
	const wallet = new ethers.Wallet('0x' + secrets.WALLET_PRIVATE_KEY, provider);
	const signer = wallet.connect(provider);
	const contract = new ethers.Contract(contractAddress, abi, signer);
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
	throw new Error(error);
}
