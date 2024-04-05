const secrets = {
    WALLET_PRIVATE_KEY:
        "0x44c04f3751b5e35344400ab7f7e561c3b80c02c2f87de69a561ecbf6d0018896",
    INFURA_API_KEY: "8acf47c71165427f8cee3a92fea12da2",
};

const ethers = await import('npm:ethers@6.10.0');
const abi = [
    'event MessageReceived(bytes32 indexed messageId, uint64 indexed sourceChainSelector, address sender, string text, address token, uint256 tokenAmount)',
  ];
const contract = new ethers.Interface(abi);

const url = `https://polygon-mumbai.infura.io/v3/${secrets.PROVIDER_API_KEY}`;
const dstContractReq = fetch(url, {
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
            address: '0xfddaffa49e71da3ef0419a303a6888f94bb5ba18',
            blockHash; '',
            topics,
        },
        ],
        id: 1,
    },
});

console.log(JSON.stringify(data));