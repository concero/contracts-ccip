import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import log from "../../../utils/log";
import { execSync } from "child_process";
import deployChildPool from "../../../deploy/08_ChildPool";
import { setChildProxyVariables } from "./setChildProxyVariables";
import deployProxyAdmin from "../../../deploy/10_ConceroProxyAdmin";
import deployTransparentProxy, { ProxyType } from "../../../deploy/11_TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";

task("deploy-child-pool", "Deploy the pool")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("skipsetvars", "Set the contract variables")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);

    if (taskArgs.deployproxy) {
      await deployProxyAdmin(hre, "childPoolProxy");
      await deployTransparentProxy(hre, "childPoolProxy");
    }

    if (taskArgs.skipdeploy) {
      log("Skipping deployment", "deploy-child-pool");
    } else {
      execSync("yarn compile", { stdio: "inherit" });

      await deployChildPool(hre);
      await upgradeProxyImplementation(hre, ProxyType.childPool, false);
    }

    if (!taskArgs.skipsetvars) {
      await setChildProxyVariables(hre);
    }
  });

export default {};
