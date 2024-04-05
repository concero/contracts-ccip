//DST
const ethers = await import('npm:ethers@6.10.0');
const abi = [
  'event MessageReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address sender, string text, address token, uint256 tokenAmount)',
];
const contract = new ethers.Interface(abi);

const chainSelectors = {
  '12532609583862916517': {
    id: 80001,
    url: 'https://polygon-mumbai.infura.io/v3/',
    conceroCCIP: '0xfddaffa49e71da3ef0419a303a6888f94bb5ba18',
  },
  '14767482510784806043': {
    id: 43113,
    url: 'https://avalanche-fuji.infura.io/v3/',
    conceroCCIP: '0xfddaffa49e71da3ef0419a303a6888f94bb5ba18',
  },
};

const topics = ['0x74bbc026808dcba59692d6a8bb20596849ca718e10e2432c6cdf48af865bc5d9'];
const [fromChainSelector, toChainSelector, token, amount, txHash, sender, receiver, blockHash] = args;

let chain = chainSelectors[toChainSelector];
if (chain) {
  const url = `${chain.url}${secrets.PROVIDER_API_KEY}`;
  const dstContractReq = Functions.makeHttpRequest({
    url,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    data: {
      jsonrpc: '2.0',
      method: 'eth_getLogs',
      params: [
        {
          removed: 'false',
          address: chainSelectors[toChainSelector].conceroCCIP,
          blockHash,
          topics,
        },
      ],
      id: 1,
    },
  });

  const { data } = await dstContractReq;
  console.log(JSON.stringify(data));
  if (data.error) {
    console.error(data.error);
    throw new Error('Error fetching destination contract address');
  }
  if (!data.result) {
    console.error(data);
    throw new Error('Result is undefined');
  }
  const filtered = data.result.filter(log => log.transactionHash === txHash);
  if (filtered.length === 0) {
    console.error(data);
    throw new Error('No logs found for txHash');
  }
  if (filtered.length > 1) {
    console.error(data);
    throw new Error('Multiple logs found for txHash');
  }
  if (filtered[0].data === '0x') {
    console.error(data);
    throw new Error('Data is empty');
  }

  const log = {
    topics: [
      ethers.id('MessageReceived(bytes32,uint64,address,string,address,uint256)'), // This is the topic for the event signature
      data.result.topics[1], // messageId
      data.result.topics[2], // sourceChainSelector
    ],
    data,
  };
  const decodedLog = contract.parseLog(log);
  console.log('Decoded log:', decodedLog);
  return Functions.encodeString(JSON.stringify(decodedLog));
  // return Functions.encodeString(JSON.stringify(filtered[0].data))
}
