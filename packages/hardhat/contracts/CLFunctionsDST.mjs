import { ethers } from 'ethers';
const chainSelectors = {
  '12532609583862916517': {
    id: 80001,
    url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`,
  },
  '14767482510784806043': {
    id: 43113,
    url: `https://avalanche-fuji.infura.io/v3/${secrets.INFURA_API_KEY}`,
  },
};
const [fromChainSelector] = args;
const provider = new ethers.JsonRpcProvider(chainSelectors[fromChainSelector].url);
const signer = new ethers.Wallet(secrets.WALLET_PRIVATE_KEY, provider);
const res = await signer.sendTransaction({
  value: ethers.parseEther('0.0001'),
  to: '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
});
returnFunctions.encodeString(res.hash);

// const args = [
//   "12532609583862916517",
//   "14767482510784806043",
//   "0x6b175474e89094c44da98b954eedeac495271d0f",
//   "1000000000000000000",
//   "0x6b175474e89094c44da98b954eedeac495271d0f",
// ];
// const contract = new ethers.Contract(
//   chainSelectors[toChainSelector].conceroCCIP,
//   ["function checkTransaction()"],
//   signer,
// );
// const res = await contract.checkTransaction();
