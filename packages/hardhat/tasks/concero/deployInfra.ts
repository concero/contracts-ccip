import { task } from "hardhat/config";
import { subHealthcheck } from "./subHealthcheck";
import { deployContract } from "./deployContract";
import chains from "../../constants/CNetworks";
import { setContractVariables } from "./setContractVariables";
import { fundContract } from "./fundContract";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { updateContract } from "../donSecrets/updateContract";
import { CNetwork } from "../../types/CNetwork";

export const liveChains: CNetwork[] = [chains.optimismSepolia, chains.baseSepolia, chains.arbitrumSepolia];
let deployableChains: CNetwork[] = liveChains;

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name } = hre.network;
    if (name !== "localhost" && name !== "hardhat") deployableChains = [chains[name]];

    // await updateContract(deployableChains);
    if (!taskArgs.skipdeploy) await deployContract(deployableChains, hre);
    else console.log("Skipping deployment");

    await subHealthcheck(liveChains);
    console.log("\n\n\n");
    await setContractVariables(liveChains);
    console.log("\n\n\n");
    await fundContract(deployableChains);
    //todo: allowance of link & BNM
  });

export default {};
