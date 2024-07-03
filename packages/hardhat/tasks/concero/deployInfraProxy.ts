import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { execSync } from "child_process";
import deployConceroProxy from "../../deploy/00_InfraProxy";

task("deploy-proxy", "Deploy the concero proxy")
  .addFlag("skipdeploy", "Skip deployment")

  .setAction(async taskArgs => {
    try {
      const hre: HardhatRuntimeEnvironment = require("hardhat");
      const { name } = hre.network;

      if (taskArgs.skipdeploy) {
        console.log("Skipping deployment");
      } else {
        execSync("yarn compile", { stdio: "inherit" });
        await deployConceroProxy(hre);
      }
    } catch (e) {
      console.error(e);
    }
  });

export default {};
