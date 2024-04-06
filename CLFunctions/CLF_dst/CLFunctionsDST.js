const dotenv = await import('npm:dotenv@10.0.0');

dotenv.config({path: "./.env"});

const address = '0x4200A2257C399C1223f8F3122971eb6fafaaA976'
const messageId = '0xb47d30d9660222539498f85cefc5337257f8e0ebeabbce312108f218555ced50'
const sender = '0x70E73f067a1fC9FE6D53151bd271715811746d3a'
const receiver = '0x70E73f067a1fC9FE6D53151bd271715811746d3a'
const amount = '1000000000000000000'
const token = '0xf1E3A5842EeEF51F2967b3F05D45DD4f4205FF40'
const INFURA_API_KEY = "8acf47c71165427f8cee3a92fea12da2";

const secrets = {
    WALLET_PRIVATE_KEY: "0x44c04f3751b5e35344400ab7f7e561c3b80c02c2f87de69a561ecbf6d0018896",
    INFURA_API_KEY: INFURA_API_KEY,
};

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
        address: address,
        topics: [null, messageId],
        fromBlock: "earliest",
        toBlock: "latest",
      },
    ]
  }),
}

const response = await fetch(url, params)
const data = await response.json()

if (data?.error) {
  console.error(data.error);
  throw new Error('Error fetching destination contract address');
}
if (!data?.result) {
  console.error(data);
  throw new Error('Result is undefined');
}

const ethers = await import('npm:ethers@6.10.0');
const strAbi = 'event CCIPSent(bytes32 indexed ccipMessageId, address sender, address recipient, address token, uint256 amount, uint64 dstChainSelector)'
const abi = [strAbi];
const contract = new ethers.Interface(abi);
const log = {
  topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]],
  data: data.result[0].data
};
const decodedLog = contract.parseLog(log);
console.log('Decoded log:', decodedLog);
// return Functions.encodeString(JSON.stringify(decodedLog));
// return Functions.encodeString(JSON.stringify(filtered[0].data))
