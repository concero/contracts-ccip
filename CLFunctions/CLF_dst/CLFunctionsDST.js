const ethers = await import('npm:ethers@6.10.0');
const [srcContractAddress, messageId] = args;
const params = {
 url: `https://polygon-mumbai.infura.io/v3/${secrets.INFURA_API_KEY}`,
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
    fromBlock: 'earliest',
    toBlock: 'latest',
   },
  ],
 },
};
const response = await Functions.makeHttpRequest(params);
const { data } = response;
if (data?.error || !data?.result) {
 throw new Error('Error fetching logs');
}
const abi = ['event CCIPSent(bytes32 indexed, address, address, address, uint256, uint64)'];
const contract = new ethers.Interface(abi);
const log = {
 topics: [ethers.id('CCIPSent(bytes32,address,address,address,uint256,uint64)'), data.result[0].topics[1]],
 data: data.result[0].data,
};
const decodedLog = contract.parseLog(log);
const croppedArgs = args.slice(1);
for (let i = 0; i < decodedLog.args.length; i++) {
 if (decodedLog.args[i].toString().toLowerCase() !== croppedArgs[i].toString().toLowerCase()) {
  throw new Error('Message ID does not match the event log');
 }
}
return Functions.encodeUint256(BigInt(messageId));


// command for removing \n symbols:  sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' -e 's/\t/ /g' CLFunctionsDST.js
