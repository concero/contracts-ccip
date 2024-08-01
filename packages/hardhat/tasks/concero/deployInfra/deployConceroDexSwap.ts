import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CNetwork } from "../../../types/CNetwork";
import { liveChains } from "../liveChains";
import CNetworks from "../../../constants/CNetworks";
import { execSync } from "child_process";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";

task("deploy-dex-swap", "Deploy the concero dex swap contract")
  .addFlag("skipdeploy", "Skip deployment")
  .setAction(async taskArgs => {
    try {
      const hre: HardhatRuntimeEnvironment = require("hardhat");
      const { name } = hre.network;
      let deployableChains: CNetwork[] = liveChains;

      if (name !== "localhost" && name !== "hardhat") {
        deployableChains = [CNetworks[name]];
      }

      if (taskArgs.skipdeploy) {
        console.log("Skipping deployment");
      } else {
        execSync("yarn compile", { stdio: "inherit" });
        await deployConceroDexSwap(hre);
      }
    } catch (e) {
      console.error(e);
    }
  });

export default {};
