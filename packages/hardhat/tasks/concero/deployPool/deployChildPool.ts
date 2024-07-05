import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../../../constants/CNetworks";
import log from "../../../utils/log";
import { execSync } from "child_process";
import { CNetwork } from "../../../types/CNetwork";
import { liveChains } from "../liveChains";
import deployChildPool from "../../../deploy/08_ChildPool";
import deployChildProxy from "../../../deploy/02_ChildPoolProxy";
import { setChildPoolProxyImplementation } from "./setChildPoolProxyImplementation";
import { setChildProxyVariables } from "./setChildProxyVariables";

task("deploy-child-pool", "Deploy the pool")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("skipsetvars", "Set the contract variables")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;
    const deployableChains: CNetwork[] = liveChains.filter(
      (chain: CNetwork) => chain.chainId !== chains.baseSepolia.chainId && chain.chainId !== chains.base.chainId,
    );

    if (taskArgs.deployproxy) {
      await deployChildProxy(hre);
    }

    if (taskArgs.skipdeploy) {
      log("Skipping deployment", "deploy-child-pool");
    } else {
      execSync("yarn compile", { stdio: "inherit" });

      await deployChildPool(hre);
      await setChildPoolProxyImplementation(hre, deployableChains);
    }

    if (!taskArgs.skipsetvars) {
      await setChildProxyVariables(hre);
    }
  });

export default {};
