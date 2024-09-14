import CNetworks from "../../constants/CNetworks";
import { privateKeyToAccount } from "viem/accounts";
import log from "../../utils/log";
import { task } from "hardhat/config";
import { abi as ownableAbi } from "@openzeppelin/contracts/build/contracts/Ownable.json";
import { viemReceiptConfig } from "../../constants/deploymentVariables";
import { getFallbackClients } from "../../utils/getViemClients";

export async function changeOwnership(hre, targetContract, newOwner: string) {
  const { name: chainName } = hre.network;
  const chainId = hre.network.config.chainId;
  const { viemChain, url } = CNetworks[chainName];

  if (!viemChain) {
    log(`Chain ${chainId} not found in live chains`, "changeOwnership");
    return;
  }

  const viemAccount = privateKeyToAccount(`0x${process.env.PROXY_DEPLOYER_PRIVATE_KEY}`);
  const { walletClient, publicClient } = getFallbackClients(chain, viemAccount);

  const txHash = await walletClient.writeContract({
    address: targetContract,
    abi: ownableAbi,
    functionName: "transferOwnership",
    account: viemAccount,
    args: [newOwner],
    chain: viemChain,
    gas: 200_000n,
  });

  const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ ...viemReceiptConfig, hash: txHash });

  log(`Change Ownership: gasUsed: ${cumulativeGasUsed}, hash: ${txHash}`, "changeOwnership");
}

task("change-ownership", "Changes the ownership of the contract")
  .addParam("newowner", "The address of the new owner")
  .addParam("targetcontract", "The address of the target contract")
  .setAction(async taskArgs => {
    const { name, live } = hre.network;
    if (live) {
      await changeOwnership(hre, taskArgs.targetcontract, taskArgs.newowner);
    }
  });

export default {};
