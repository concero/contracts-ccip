import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../types/CNetwork";
import { liveChains } from "./liveChains";
import CNetworks from "../../constants/CNetworks";
import { execSync } from "child_process";
import deployConceroOrchestrator from "../../deploy/01_ConceroOrchestrator";

task("deploy-orchestrator", "Deploy the concero orchestrator").setAction(async taskArgs => {
  try {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name } = hre.network;
    let deployableChains: CNetwork[] = liveChains;

    if (name !== "localhost" && name !== "hardhat") {
      deployableChains = [CNetworks[name]];
    }

    execSync("yarn compile", { stdio: "inherit" });
    await deployConceroOrchestrator(hre);
  } catch (e) {
    console.error(e);
  }
});

export default {};
