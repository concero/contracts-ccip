import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import deployChildPool from "../../../deploy/08_ChildPool";
import { setChildProxyVariables } from "./setChildProxyVariables";
import deployProxyAdmin from "../../../deploy/10_ConceroProxyAdmin";
import deployTransparentProxy from "../../../deploy/11_TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
import { compileContracts } from "../../../utils/compileContracts";
import { ProxyType } from "../../../constants/deploymentVariables";

task("deploy-child-pool", "Deploy the pool")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("deployimplementation", "Deploy the implementation")
  .addFlag("setvars", "Set the contract variables")
  .setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat");
    compileContracts({ quiet: true });

    if (taskArgs.deployproxy) {
      await deployProxyAdmin(hre, ProxyType.childPoolProxy);
      await deployTransparentProxy(hre, ProxyType.childPoolProxy);
    }

    if (taskArgs.deployimplementation) {
      await deployChildPool(hre);
      await upgradeProxyImplementation(hre, ProxyType.childPoolProxy, false);
    }

    if (taskArgs.setvars) {
      await setChildProxyVariables(hre);
    }
  });

export default {};
