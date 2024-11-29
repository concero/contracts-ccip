import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { compileContracts } from "../../../utils";
import { setConceroContractSenders, setParentPoolCap, setParentPoolJsHashes, setParentPoolSecretsVersion, setParentPoolVariables, setPools } from "./setParentPoolVariables";
import { conceroNetworks } from "../../../constants";
import { CNetwork } from "../../../types/CNetwork";

task("set-parent-pool-variables", "Sets the parent pool variables")
    .addFlag("setjshashes", "Set the JS hashes")
    .addFlag("setcap", "Set the cap")
    .addFlag("setsecretsversion", "Set the secrets version")
    .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
    .addFlag("setsenders", "Set the senders")
    .addFlag("setpools", "Set the pools")
    .addOptionalParam("rebalance", "Rebalance the pools", false, types.boolean)
    .addOptionalParam("all", "Set all variables", false, types.boolean)
    .setAction(async taskArgs => {
        const hre: HardhatRuntimeEnvironment = require("hardhat");
        compileContracts({ quiet: true });

        const { name } = hre.network;
        const deployableChains: CNetwork[] = [conceroNetworks[name]];

        const { setjshashes, setcap, setsecretsversion, slotid, setsenders, setpools, all, rebalance } = taskArgs

        if (all) {
            await setParentPoolVariables(deployableChains[0], slotid, rebalance);
        } else {
            const { abi: ParentPoolAbi } = await import("../../../artifacts/contracts/ParentPool.sol/ParentPool.json");
            if (setjshashes) await setParentPoolJsHashes(deployableChains[0], ParentPoolAbi);
            if (setcap) await setParentPoolCap(deployableChains[0], ParentPoolAbi);
            if (setsecretsversion) await setParentPoolSecretsVersion(deployableChains[0], ParentPoolAbi, slotid);
            if (setsenders) await setConceroContractSenders(deployableChains[0], ParentPoolAbi);
            if (setpools) await setPools(deployableChains[0], ParentPoolAbi, rebalance);
        }
    })

export default {};