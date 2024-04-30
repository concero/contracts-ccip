import { CNetwork } from "../types/CNetwork";
import { getClients } from "./switchChain";
/* ЛЮТЫЙ ДРИП */
export async function dripCCIPBnM(chains: CNetwork[], amount: number = 20) {
  for (const chain of chains) {
    const { ccipBnmToken, viemChain, url, name } = chain;
    const { walletClient, publicClient, account } = getClients(viemChain, url);
    const gasPrice = await publicClient.getGasPrice();

    for (let i = 0; i < amount; i++) {
      const { request: sendReq } = await publicClient.simulateContract({
        functionName: "drip",
        abi: [
          { inputs: [{ internalType: "address", name: "to", type: "address" }], name: "drip", outputs: [], stateMutability: "nonpayable", type: "function" },
        ],
        account,
        address: ccipBnmToken,
        args: [account.address],
        gasPrice,
      });

      const sendHash = await walletClient.writeContract(sendReq);
      const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({ hash: sendHash });
      console.log(`Sent 1 CCIPBNM token to ${name}:${account.address}. Gas used: ${sendGasUsed.toString()}`);
    }
  }
}

export async function dripCCIPBnmMulticall(chains: CNetwork[], amount: number: 20) {
  for (const chain of chains) {
    const { ccipBnmToken, viemChain, url, name } = chain;
    const { walletClient, publicClient, account } = getClients(viemChain, url);
    const gasPrice = await publicClient.getGasPrice();
    const { request: sendReq } = await walletClient.multicall({
      functionName: "drip",
      abi: [
        { inputs: [{ internalType: "address", name: "to", type: "address" }], name: "drip", outputs: [], stateMutability: "nonpayable", type: "function" },
      ],
      account,
      address: ccipBnmToken,
      args: [account.address],
      gasPrice,
    });
    const sendHash = await walletClient.writeContract(sendReq);
    const { cumulativeGasUsed: sendGasUsed } = await publicClient.waitForTransactionReceipt({ hash: sendHash });
    console.log(`Sent ${amount} CCIPBNM tokens to ${name}:${account.address}. Gas used: ${sendGasUsed.toString()}`);
  }
}