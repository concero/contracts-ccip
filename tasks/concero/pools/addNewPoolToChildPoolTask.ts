import { task } from "hardhat/config";
import { conceroNetworks, ProxyEnum } from "../../../constants";
import { getEnvAddress, getFallbackClients } from "../../../utils";

task("add-new-pool-to-parent-pool", "Add a new pool to the parent pool")
  .addParam("newchain", "", "")
  .setAction(async taskArgs => {
    console.log(`Adding ${taskArgs.newchain} to the parent pool`);
    const hre = require("hardhat");
    const currentPoolChain = conceroNetworks[hre.network.name];
    const { publicClient, walletClient } = getFallbackClients(currentPoolChain);
    const { abi: ChildPoolAbi } = await import("../../../artifacts/contracts/ChildPool.sol/ChildPool.json");
    const newPoolChain = conceroNetworks[taskArgs.newchain];
    if (!newPoolChain) {
      throw new Error(`No chain found for ${taskArgs.newchain}`);
    }
    const newPoolChainSelector = newPoolChain.chainSelector;
    const [newPoolAddress] = getEnvAddress(ProxyEnum.childPoolProxy, newPoolChain.name);

    const txHash = await walletClient.writeContract({
      abi: ChildPoolAbi,
      functionName: "setPools",
      args: [newPoolChainSelector, newPoolAddress, true],
      gas: 3_000_000n,
    });

    const { status } = await publicClient.waitForTransactionReceipt({ hash: txHash });

    if (status === "reverted") {
      throw new Error(`Transaction failed: ${txHash}`);
    } else {
      console.log(`Transaction successful: ${txHash}`);
    }
  });

export default {};
