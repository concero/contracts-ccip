import { ethers } from "ethers-v5";
import { ethers as ethersv6 } from "ethers"; //v6;

//todo: deployer PK to be passed as arg
export function getEthersSignerAndProvider(chain_url: string) {
  const provider = new ethers.providers.JsonRpcProvider(chain_url);
  const signer = new ethers.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);

  return { signer, provider };
}

export function getEthersV6SignerAndProvider(chain_url: string) {
  const provider = new ethersv6.JsonRpcProvider(chain_url);
  const signer = new ethersv6.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);

  return { signer, provider };
}
