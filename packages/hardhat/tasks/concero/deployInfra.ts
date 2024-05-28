import { task, types } from "hardhat/config";
import { fundSubscription } from "./fundSubscription";
import chains from "../../constants/CNetworks";
import { setContractVariables } from "./setContractVariables";
import { fundContract } from "./fundContract";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../types/CNetwork";
import log from "../../utils/log";
import uploadDonSecrets from "../donSecrets/upload";
import deployConcero from "../../deploy/02_Concero";
import { execSync } from "child_process";

export const liveChains: CNetwork[] = [chains.baseSepolia, chains.arbitrumSepolia, chains.optimismSepolia];
let deployableChains: CNetwork[] = liveChains;

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  // .addFlag("all", "Deploy the contract to all networks")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;

    // if (taskArgs.all) deployableChains = liveChains;
    // else
    if (name !== "localhost" && name !== "hardhat") deployableChains = [chains[name]];

    if (taskArgs.skipdeploy) log("Skipping deployment", "deploy-infra");
    else {
      execSync("yarn compile", { stdio: "inherit" });
      await deployConcero(hre, { slotId });
    }

    await uploadDonSecrets(deployableChains, slotId, 4320);
    await setContractVariables(liveChains, deployableChains, slotId);
    await fundSubscription(liveChains);
    await fundContract(deployableChains);
    //todo: allowance of link & BNM
  });

export default {};
