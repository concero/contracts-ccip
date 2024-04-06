const url = `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`;
const params = {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    jsonrpc: '2.0',
    method: 'eth_getLogs',
    id: 1,
    params: [
      {
        address: args[0],
        topics: [null, args[1]],
        fromBlock: "earliest",
        toBlock: "latest",
      },
    ]
  }),
}

const response = await fetch(url, params)
const data = await response.json()

if (data?.error || !data?.result) {
  throw new Error('Error fetching destination contract address');
}

const ethers = await import('npm:ethers@6.10.0');
const abi = ['event CCIPSent(bytes32 indexed ccipMessageId, address sender, address recipient, address token, uint256 amount, uint64 dstChainSelector)'];
const contract = new ethers.Interface(abi);
const log = {
  topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]],
  data: data.result[0].data
};
const decodedLog = contract.parseLog(log);
return Functions.encodeString(decodedLog.args);
