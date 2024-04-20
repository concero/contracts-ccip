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
    const { url, viemChain } = chains[networkName];

    const account = privateKeyToAccount(`0x${process.env.DEPLOYER_PRIVATE_KEY}`);
    const walletClient = createWalletClient({ transport: http(url), chain: networks[networkName], account });
    const publicClient = createPublicClient({ transport: http(url), chain: networks[networkName] });

    for (const [name, dstContract] of Object.entries(contracts)) {
      if (name !== networkName) {
        const { chainSelector } = chains[name];
        const { request: setDstConceroContractReq } = await publicClient.simulateContract({
          address: contractAddress,
          abi,
          functionName: "setDstConceroContract",
          account,
          args: [chainSelector, dstContract.toLowerCase()],
          chain: viemChain,
        });
        const setDstConceroContractHash = await walletClient.writeContract(setDstConceroContractReq);
        const { cumulativeGasUsed: setDstConceroContractGasUsed } = await publicClient.waitForTransactionReceipt({ hash: setDstConceroContractHash });
        console.log(`Set ${networkName}:${contractAddress} dstConceroContract[${name}, ${dstContract}]. Gas used: ${setDstConceroContractGasUsed.toString()}`);

        const { request: setAllowDestinationChainReq } = await publicClient.simulateContract({
          address: contractAddress,
          abi,
          functionName: "setAllowDestinationChain",
          account,
          args: [chainSelector, true],
          chain: viemChain,
        });
        const setAllowDestinationChainHash = await walletClient.writeContract(setAllowDestinationChainReq);
        const { cumulativeGasUsed: setAllowDestinationChainGasUsed } = await publicClient.waitForTransactionReceipt({ hash: setAllowDestinationChainHash });
        console.log(`Set ${networkName}:${contractAddress} allowDestinationChain[${name}, true]. Gas used: ${setAllowDestinationChainGasUsed.toString()}`);

        const { request: setAllowSourceChainReq } = await publicClient.simulateContract({
          address: contractAddress,
          abi,
          functionName: "setAllowSourceChain",
          account,
          args: [chainSelector, true],
          chain: viemChain,
        });
        const setAllowSourceChainHash = await walletClient.writeContract(setAllowSourceChainReq);
        const { cumulativeGasUsed: setAllowSourceChainGasUsed } = await publicClient.waitForTransactionReceipt({ hash: setAllowSourceChainHash });
        console.log(`Set ${networkName}:${contractAddress} allowSourceChain[${name}, true]. Gas used: ${setAllowSourceChainGasUsed.toString()}`);
      }
    }

    try {
      const { request: addToAllowlistReq } = await publicClient.simulateContract({
        address: contractAddress,
        abi,
        functionName: "addToAllowlist",
        account,
        args: [process.env.MESSENGER_WALLET_ADDRESS],
        chain: viemChain,
      });
      const addToAllowlistHash = await walletClient.writeContract(addToAllowlistReq);
      const { cumulativeGasUsed: addToAllowlistGasUsed } = await publicClient.waitForTransactionReceipt({ hash: addToAllowlistHash });
      console.log(`Added ${process.env.MESSENGER_WALLET_ADDRESS} to allowlist. Gas used: ${addToAllowlistGasUsed.toString()}`);
    } catch (e) {
      console.log(`Failed to add ${process.env.MESSENGER_WALLET_ADDRESS} to allowlist: ${e}`);
    }
  }
}
