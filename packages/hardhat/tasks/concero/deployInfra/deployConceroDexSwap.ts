import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployConceroDexSwap from "../../../deploy/03_ConceroDexSwap";

task("deploy-dex-swap", "Deploy the concero dex swap contract").setAction(async taskArgs => {
  try {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const { live } = hre.network;
    await deployConceroDexSwap(hre);
  } catch (e) {
    console.error(e);
  }
});

export default {};
