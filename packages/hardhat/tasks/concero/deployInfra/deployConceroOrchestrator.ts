import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroOrchestrator from "../../../deploy/ConceroOrchestrator";

task("deploy-orchestrator", "Deploy the concero orchestrator").setAction(async taskArgs => {
  try {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name, live } = hre.network;

    await deployConceroOrchestrator(hre);
  } catch (e) {
    console.error(e);
  }
});

export default {};
