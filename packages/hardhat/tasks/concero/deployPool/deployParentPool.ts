import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../../../constants/CNetworks";
import { getEnvVar } from "../../../utils/getEnvVar";
import addCLFConsumer from "../../sub/add";
import log from "../../../utils/log";
import { execSync } from "child_process";
import uploadDonSecrets from "../../donSecrets/upload";
import { CNetwork } from "../../../types/CNetwork";
import deployParentPoolProxy from "../../../deploy/01_ParentPoolProxy";
import deployParentPool from "../../../deploy/09_ParentPool";
import { setParentPoolVariables } from "./setParentPoolVariables";
import { setParentPoolProxyImplementation } from "./setParentPoolProxyImplementation";

task("deploy-parent-pool", "Deploy the pool")
  .addFlag("skipdeploy", "Deploy the contract to a specific network")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("skipsetvars", "Set the contract variables")
  .addFlag("uploadsecrets", "Set the contract variables")
  .addFlag("mainnet", "Deploy to mainnet")
  .setAction(async taskArgs => {
    execSync("yarn compile", { stdio: "inherit" });

    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;
    let deployableChains: CNetwork[] = [chains.baseSepolia];

    if (taskArgs.ismainnet) {
      deployableChains = [chains.base];
    }

    if (taskArgs.deployproxy) {
      await deployParentPoolProxy(hre);
      const proxyAddress = getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`);
      const { functionsSubIds } = chains[name];
      await addCLFConsumer(chains[name], [proxyAddress], functionsSubIds[0]);
    }

    if (taskArgs.skipdeploy) {
      log("Skipping deployment", "deploy-parent-pool");
    } else {
      await deployParentPool(hre);
      await setParentPoolProxyImplementation(hre, deployableChains);
    }

    if (taskArgs.uploadsecrets) {
      await uploadDonSecrets(deployableChains, slotId, 4320);
    }

    if (!taskArgs.skipsetvars && !taskArgs.deployproxy) {
      await setParentPoolVariables(deployableChains[0], taskArgs.uploadsecrets, slotId);
    }
  });

export default {};
