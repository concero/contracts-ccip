//SRC
const ethers = await import("npm:ethers@6.10.0");

class FunctionsJsonRpcProvider extends ethers.JsonRpcProvider {
    constructor(url) {
        super(url)
        this.url = url
    }

    async _send(payload) {
        let resp = await fetch(this.url, {
            method: "POST",
            headers: {"Content-Type": "application/json"},
            body: JSON.stringify(payload),
        })
        return resp.json()
    }
}

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
const provider = new FunctionsJsonRpcProvider(chainSelectors[fromChainSelector].url);
const signer = new ethers.Wallet(secrets.WALLET_PRIVATE_KEY, provider);
const res = await signer.sendTransaction({
    value: ethers.parseEther('0.0001'),
    to: '0x70E73f067a1fC9FE6D53151bd271715811746d3a',
});
console.log(res)
return Functions.encodeString(res.hash);
