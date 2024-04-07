/*
Simulation requirements:
numAllowedQueries: 2 – a minimum to initialise Viem.
 */

// CUSTOM TRANSPORT FUNCTIONS
// import { Functions } from '../utils/sandbox.ts';

// const secrets = {
//  WALLET_PRIVATE_KEY: '44c04f3751b5e35344400ab7f7e561c3b80c02c2f87de69a561ecbf6d0018896',
//  INFURA_API_KEY: '8acf47c71165427f8cee3a92fea12da2',
// };
// const args = ["12532609583862916517"];
// const chainSelectors = {
//     "12532609583862916517": {id: 80001, url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`},
//     "14767482510784806043": {id: 43113, url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`}
// };

// async function sendTx() {
// const url = `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`;

const url = `https://polygon-mumbai.gateway.tenderly.co`;
const { createWalletClient, custom } = await import('npm:viem');
const { privateKeyToAccount } = await import('npm:viem/accounts');
const { polygonMumbai } = await import('npm:viem/chains');

try {
 const client = createWalletClient({
  chain: polygonMumbai,
  transport: custom({
   async request({ method, params }) {
    if (method === 'eth_chainId') return '0x13881';
    if (method === 'eth_estimateGas') return '0x3d090';
    if (method === 'eth_maxPriorityFeePerGas') return '0x3b9aca00';
    const response = await Functions.makeHttpRequest({
     url,
     method: 'post',
     headers: { 'Content-Type': 'application/json' },
     data: { jsonrpc: '2.0', id: 1, method, params },
    });
    return response.data.result;
   },
  }),
 });
 const account = privateKeyToAccount('0x' + secrets.WALLET_PRIVATE_KEY);
 const abi = [
  {
   name: 'addUnconfirmedTX',
   type: 'function',
   inputs: [
    { type: 'bytes32', name: 'ccipMessageId' },
    { type: 'address', name: 'sender' },
    { type: 'address', name: 'recipient' },
    { type: 'uint256', name: 'amount' },
    { type: 'uint64', name: 'srcChainSelector' },
    { type: 'address', name: 'token' },
   ],
   outputs: [],
  },
 ];
 const hash = await client.writeContract({
  account,
  abi,
  address: '0x59d607709841174d20aAFc5e8A1357C4940e8e9F',
  args: [
   '0x8b666e9ea0f849048bfb59996e02f0082df9298550249d7c6cefec78e7e24cd8',
   '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
   '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
   '1000000000000000000',
   parseInt('12532609583862916517'),
   '0x9999f7Fea5938fD3b1E26A12c3f2fb024e194f97',
  ],
  chain: polygonMumbai,
 });
 return Functions.encodeString(hash);
} catch (error) {
 return Functions.encodeString('error');
}
