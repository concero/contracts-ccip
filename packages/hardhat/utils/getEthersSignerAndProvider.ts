import { ethers } from "ethers-v5";
import { ethers as ethersv6 } from "ethers";
import { urls } from "../constants";
import { type CNetworkNames } from "../types/CNetwork";
//todo: deployer PK to be passed as arg
//todo: rename to getEthersV5SignerAndProvider
//todo: make sure v5 is only used in chainlink functions subscriptionManager, remove v5 from setContractVariables and other non-clf tasks

export function getEthersSignerAndProvider(chain_url: string) {
  const provider = new ethers.providers.JsonRpcProvider(chain_url);
  const signer = new ethers.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);

  return { signer, provider };
}

export function getEthersV5FallbackSignerAndProvider(networkName: CNetworkNames) {
  const providers = urls[networkName].map(url => new ethers.providers.JsonRpcProvider(url));
  const fallbackProvider = new ethers.providers.FallbackProvider(providers);
  const signer = new ethers.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, fallbackProvider);

  return { signer, fallbackProvider };
}

export function getEthersV6SignerAndProvider(chain_url: string) {
  const provider = new ethersv6.JsonRpcProvider(chain_url);
  const signer = new ethersv6.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, provider);

  return { signer, provider };
}

export function getEthersV6FallbackSignerAndProvider(networkName: CNetworkNames): {
  signer: ethersv6.Wallet;
  provider: ethersv6.FallbackProvider;
} {
  const providers = urls[networkName].map(url => new ethersv6.JsonRpcProvider(url));
  const fallbackProvider = new ethersv6.FallbackProvider(providers);
  const signer = new ethersv6.Wallet(`0x${process.env.DEPLOYER_PRIVATE_KEY}`, fallbackProvider);

  return { signer, provider: fallbackProvider };
}
