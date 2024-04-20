import chains from "../constants/CNetworks";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, getContract, http } from "viem";
import { abi } from "../artifacts/contracts/Concero.sol/Concero.json";

export async function setContractVariables(networks) {
  const contracts = {
    baseSepolia: process.env.CONCEROCCIP_BASE_SEPOLIA,
    optimismSepolia: process.env.CONCEROCCIP_OPTIMISM_SEPOLIA,
    arbitrumSepolia: process.env.CONCEROCCIP_ARBITRUM_SEPOLIA,
  };

  for (const [networkName, contractAddress] of Object.entries(contracts)) {
    const { url } = chains[networkName];

    const account = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
    const walletClient = createWalletClient({ transport: http(url), chain: networks[networkName], account });
    const publicClient = createPublicClient({ transport: http(url), chain: networks[networkName] });

    for (const [name, dstContract] of Object.entries(contracts)) {
      if (name !== networkName) {
        const { chainSelector } = chains[networkName];
        const contract = getContract({
          address: contractAddress,
          abi,
          client: { public: publicClient, wallet: walletClient },
        });
        const hash = await contract.write.setDstConceroContract([chainSelector, dstContract.toLowerCase()]);
        const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash });
        console.log(`Set ${networkName}:${contractAddress} dstConceroContract[${name}, ${dstContract}]. Gas used: ${cumulativeGasUsed.toString()}`);
      }
    }
  }
}
