import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { compileContracts, getEnvAddress, getFallbackClients, log } from "../../../utils";
import { conceroNetworks, ProxyEnum } from "../../../constants";
import { CNetwork } from "../../../types/CNetwork";

async function removeChildPoolFromParentPool(parentPoolChain: CNetwork, chainToRemove: CNetwork) {
    const [parentPoolProxy] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolChain.name);
    const { walletClient, publicClient, account } = getFallbackClients(parentPoolChain);
    const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

    const { request: removeChildPoolReq } = await publicClient.simulateContract({
        address: parentPoolProxy,
        functionName: "removePools",
        args: [chainToRemove.chainSelector],
        abi: ParentPoolAbi,
        account,
    });

    const removeChildPoolHash = await walletClient.writeContract(removeChildPoolReq);
    const { cumulativeGasUsed } = await publicClient.waitForTransactionReceipt({ hash: removeChildPoolHash });

    log(`[Set] ${parentPoolProxy}.removeChildPool(${chainToRemove.name}). Gas: ${cumulativeGasUsed}`, "removeChildPool");
}

task("remove-child-pool-from-parent-pool", "")
    .addParam("childpoolchain", "The child pool chain to remove from the parent pool")
    .setAction(async taskArgs => {
        compileContracts({ quiet: true });

        const hre: HardhatRuntimeEnvironment = require("hardhat");
        const parentPoolChain = conceroNetworks[hre.network.name];
        const chainToRemove = conceroNetworks[taskArgs.childpoolchain];

        if (!chainToRemove) {
            log(`[Set] Chain ${taskArgs.childpoolchain} not found`, "chain-not-found", taskArgs.childpoolchain);
            return;
        }

        await removeChildPoolFromParentPool(parentPoolChain, chainToRemove);
    });

export default {};