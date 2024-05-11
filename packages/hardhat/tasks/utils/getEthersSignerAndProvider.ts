import { ethers } from "ethers-v5";

export function getEthersSignerAndProvider(chain: any) {
  const provider = new ethers.providers.JsonRpcProvider(chain.url);
  const signer = new ethers.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);

  return { signer, provider };
}
