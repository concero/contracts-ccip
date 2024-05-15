import { ethers } from "ethers-v5";

export function getEthersSignerAndProvider(chain_url: string) {
  const provider = new ethers.providers.JsonRpcProvider(chain_url);
  const signer = new ethers.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);

  return { signer, provider };
}
