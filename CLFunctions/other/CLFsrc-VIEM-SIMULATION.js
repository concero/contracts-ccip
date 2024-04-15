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
