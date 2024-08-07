import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { execSync } from "child_process";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";

task("deploy-dex-swap", "Deploy the concero dex swap contract").setAction(async taskArgs => {
  try {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { name, live } = hre.network;

    execSync("yarn compile", { stdio: "inherit" });
    await deployConceroDexSwap(hre);
  } catch (e) {
    console.error(e);
  }
});

export default {};
