const chainSelectors = {
  12532609583862916517: {
    id: 80001,
    url: "https://polygon-mumbai.infura.io/v3/",
    conceroCCIP: "0x4b1f1e2435a9c96f7330faea190ef6e7b0b1b1a7",
  },
  14767482510784806043: {
    id: 43113,
    url: "https://avalanche-fuji.infura.io/v3/",
    conceroCCIP: "0x4b1f1e2435a9c96f7330faea190ef6e7b0b1b1a7",
  },
};

const topics = ["0x74bbc026808dcba59692d6a8bb20596849ca718e10e2432c6cdf48af865bc5d9"];
const [fromChainSelector, toChainSelector, token, amount, none, txHash, sender, receiver, blockHash] = args;

let chain = chainSelectors[toChainSelector];
if (chain) {
  const url = `${chain.url}${secrets.PROVIDER_API_KEY}`;
  const dstContractReq = Functions.makeHttpRequest({
    url,
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    data: {
      jsonrpc: "2.0",
      method: "eth_getLogs",
      params: [
        {
          removed: "false",
          address: chainSelectors[toChainSelector].conceroCCIP,
          blockHash,
          topics,
        },
      ],
      id: 1,
    },
  });
  const dstContractRes = await dstContractReq;
  if (dstContractRes.error) throw new Error("Error fetching destination contract address");
  if (!dstContractRes.result) throw new Error("Result is undefined");
  const filtered = dstContractRes.result.filter(log => log.transactionHash === txHash);
  if (filtered.length === 0) throw new Error("No logs found for txHash");
  if (filtered.length > 1) throw new Error("Multiple logs found for txHash");
  if (filtered[0].data === "0x") throw new Error("Data is empty");
  return filtered[0].data;
}
