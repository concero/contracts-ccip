import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { compileContracts, err, formatGas, getEnvAddress, getFallbackClients, log } from "../../../utils";
import { conceroNetworks, ProxyEnum, viemReceiptConfig } from "../../../constants";
import { CNetwork } from "../../../types/CNetwork";

async function addParentPoolChildPool(parentPoolChain: CNetwork, chainToAdd: CNetwork, rebalance: boolean) {
    const { name: parentPoolName } = parentPoolChain;
    const { walletClient, publicClient, account } = getFallbackClients(parentPoolChain);
    const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");

    try {
        if (parentPoolChain.chainId !== chainToAdd.chainId) {
            const { name: chainToAddName, chainSelector: chainToAddSelector } = chainToAdd;

            const [parentPoolProxy, parentPoolProxyAlias] = getEnvAddress(ProxyEnum.parentPoolProxy, parentPoolName);
            const [childPoolProxy, childPoolProxyAlias] = getEnvAddress(ProxyEnum.childPoolProxy, chainToAddName);

            const { request: setReceiverReq } = await publicClient.simulateContract({
                address: parentPoolProxy,
                functionName: "setPools",
                args: [BigInt(chainToAddSelector), childPoolProxy, rebalance],
                abi: ParentPoolAbi,
                account,
            });
            const setReceiverHash = await walletClient.writeContract(setReceiverReq);
            const { cumulativeGasUsed: setReceiverGasUsed } = await publicClient.waitForTransactionReceipt({
                ...viemReceiptConfig,
                hash: setReceiverHash,
            });
            log(
                `[Set] ${parentPoolProxyAlias}.pool[${chainToAddName}] -> ${childPoolProxyAlias}. Gas: ${formatGas(setReceiverGasUsed)}`,
                "setPools",
                parentPoolName,
            );
        }
    } catch (error) {
        err(`Error ${error?.message}`, "setPools", parentPoolName);
    }
}


task("add-child-pool-to-parent-pool", "Add the child pool with rebalance option")
    .addParam("childpoolchain", "The child pool chain to add in the parent pool")
    .addOptionalParam("rebalance", "Rebalance the pool", true, types.boolean)
    .setAction(async taskArgs => {
        compileContracts({ quiet: true });

        const hre: HardhatRuntimeEnvironment = require("hardhat");
        const parentPoolChain = conceroNetworks[hre.network.name];
        const chainToAdd = conceroNetworks[taskArgs.childpoolchain];
        const rebalance = Boolean(taskArgs.rebalance);

        if (!chainToAdd) {
            log(`[Set] Chain ${taskArgs.childpoolchain} not found`, "chain-not-found", taskArgs.childpoolchain);
            return;
        }

        await addParentPoolChildPool(parentPoolChain, chainToAdd, rebalance);

    });

export default {};
