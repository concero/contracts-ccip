import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../../../constants/CNetworks";
import CNetworks from "../../../constants/CNetworks";
import { getEnvAddress } from "../../../utils/getEnvVar";
import addCLFConsumer from "../../sub/add";
import uploadDonSecrets from "../../donSecrets/upload";
import { CNetwork } from "../../../types/CNetwork";
import { setParentPoolVariables } from "./setParentPoolVariables";
import deployParentPool from "../../../deploy/09_ParentPool";
import deployTransparentProxy from "../../../deploy/11_TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
import deployProxyAdmin from "../../../deploy/10_ConceroProxyAdmin";
import { compileContracts } from "../../../utils/compileContracts";

task("deploy-parent-pool", "Deploy the pool")
  .addFlag("deployproxy", "Deploy the proxy")
  .addFlag("deployimplementation", "Deploy the implementation")
  .addOptionalParam("slotid", "DON-Hosted secrets slot id", 0, types.int)
  .addFlag("setvars", "Set the contract variables")
  .addFlag("uploadsecrets", "Set the contract variables")
  .setAction(async taskArgs => {
    compileContracts({ quiet: true });

    const hre: HardhatRuntimeEnvironment = require("hardhat");
    const slotId = parseInt(taskArgs.slotid);
    const { name } = hre.network;
    const deployableChains: CNetwork[] = [CNetworks[hre.network.name]];

    if (taskArgs.deployproxy) {
      await deployProxyAdmin(hre, "parentPoolProxy");
      await deployTransparentProxy(hre, "parentPoolProxy");
      const [proxyAddress, _] = getEnvAddress("parentPoolProxy", name);
      const { functionsSubIds } = chains[name];
      await addCLFConsumer(chains[name], [proxyAddress], functionsSubIds[0]);
    }

    if (taskArgs.deployimplementation) {
      await deployParentPool(hre); //todo: not passing slotId to deployParentPool functions' constructor args
      await upgradeProxyImplementation(hre, "parentPoolProxy", false);
    }

    if (taskArgs.uploadsecrets) {
      await uploadDonSecrets(deployableChains, slotId, 4320);
    }

    if (taskArgs.setvars) {
      await setParentPoolVariables(deployableChains[0], slotId);
    }
  });

export default {};
