// const secrets = {
//     WALLET_PRIVATE_KEY:
//         "0x44c04f3751b5e35344400ab7f7e561c3b80c02c2f87de69a561ecbf6d0018896",
//     INFURA_API_KEY: "8acf47c71165427f8cee3a92fea12da2",
// };
// const args = ["12532609583862916517"];
// const chainSelectors = {
//     "12532609583862916517": {id: 80001, url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`},
//     "14767482510784806043": {id: 43113, url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`}
// };
//SRC
const { createWalletClient, http } = await import('npm:viem');
const { privateKeyToAccount } = await import('npm:viem/accounts');
const { polygonMumbai } = await import('npm:viem/chains');
import { http } from 'viem';

async function sendTx() {
  const { createWalletClient, http } = await import('npm:viem');
  const { privateKeyToAccount } = await import('npm:viem/accounts');
  const { polygonMumbai } = await import('npm:viem/chains');
  const client = createWalletClient({
    chain: polygonMumbai,
    transport: http(`https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`),
  });
  const account = privateKeyToAccount('0x' + secrets.WALLET_PRIVATE_KEY);
  const hash = await client.sendTransaction({
    account,
    to: '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
    value: 1000000n,
    chain: polygonMumbai,
  });

  console.log(`Transaction: ${hash}`);
  return Functions.makeHttpRequest();
  // const provider = new ethers.JsonRpcProvider(chainSelectors[fromChainSelector].url);
  // const signer = new ethers.Wallet(secrets.WALLET_PRIVATE_KEY, provider);

  // const res = signer.sendTransaction({
  //     value: ethers.parseEther('0.000001'),
  //     to: '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
  // }).then((tx) => {
  //     console.log(`Transaction: ${tx}`)
  // }).catch((err) => {
  //     console.log(`Error!: ${err}`)
  // })

  // return Functions.encodeString(res.hash);
}

sendTx().catch(err => {
  console.error(err);
});
