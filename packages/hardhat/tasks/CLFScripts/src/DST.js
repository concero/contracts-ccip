const ethers = await import('npm:ethers@6.10.0');
const [srcContractAddress, messageId, blockNumber] = args;

const chainMap = {
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
const params = {
	url: chainMap[args[7]].url,
	method: 'POST',
	headers: {
		'Content-Type': 'application/json',
	},
	data: {
		jsonrpc: '2.0',
		method: 'eth_getLogs',
		id: 1,
		params: [
			{
				address: srcContractAddress,
				topics: [null, messageId],
				fromBlock: blockNumber,
				toBlock: blockNumber,
			},
		],
	},
};
console.log({
	address: srcContractAddress,
	topics: [null, messageId],
	fromBlock: blockNumber,
	toBlock: blockNumber,
});
const response = await Functions.makeHttpRequest(params);
const {data} = response;
if (data?.error || !data?.result.length) {
	throw new Error('Logs not found');
}
const abi = ['event CCIPSent(bytes32 indexed, address, address, address, uint256, uint64)'];
const contract = new ethers.Interface(abi);
const log = {
	topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]],
	data: data.result[0].data,
};
const decodedLog = contract.parseLog(log);
console.log(decodedLog);
const croppedArgs = args.slice(1);
for (let i = 0; i < 6; i++) {
	if (decodedLog.args[i].toString().toLowerCase() !== croppedArgs[i].toString().toLowerCase()) {
		throw new Error('Message ID does not match the event log');
	}
}
return Functions.encodeUint256(BigInt(messageId));

// command for removing \n symbols:  sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' -e 's/\t/ /g' DST.js
