import { task } from "hardhat/config";
import { subHealthcheck } from "./subHealthcheck";
import { deployContract } from "./deployContract";
import chains from "../../constants/CNetworks";
import { execSync } from "child_process";
import { reloadDotEnv } from "../../utils/dotenvConfig";
import { setContractVariables } from "./setContractVariables";
import { fundContract } from "./fundContract";
import { HardhatRuntimeEnvironment } from "hardhat/types";

export const liveChains = [chains.optimismSepolia, chains.baseSepolia, chains.arbitrumSepolia];
export let deployableChains = liveChains;

task("deploy-infra", "Deploy the CCIP infrastructure")
  .addOptionalParam("deploy", "Deploy the contract to a specific network", "true")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");

    const { name } = hre.network;
    if (name !== "localhost" && name !== "hardhat") deployableChains = [chains[name]];

    secretsHealthcheck(deployableChains);
    if (taskArgs.deploy === "true") await deployContract(deployableChains);
    else console.log("Skipping deployment");

    await subHealthcheck(liveChains);
    await setContractVariables(liveChains);
    await fundContract(deployableChains);
    //todo: allowance of link & BNM
  });

function secretsHealthcheck(selectedChains) {
  for (const chain of selectedChains) {
    execSync(`yarn hardhat clf-donsecrets-updatecontract --network ${chain.name}`, { stdio: "inherit" });
  }
  reloadDotEnv();
}

// secretsHealthcheck(liveChains);

export default {};
