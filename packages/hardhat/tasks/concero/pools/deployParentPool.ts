import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { cNetworks, ProxyEnum } from "../../../constants";
import { compileContracts, getEnvAddress } from "../../../utils";
import addCLFConsumer from "../../CLF/subscriptions/add";
import uploadDonSecrets from "../../CLF/donSecrets/upload";
import { CNetwork } from "../../../types/CNetwork";
import { setParentPoolVariables } from "./setParentPoolVariables";
import deployTransparentProxy from "../../../deploy/TransparentProxy";
import { upgradeProxyImplementation } from "../upgradeProxyImplementation";
import deployParentPool from "../../../deploy/ParentPool";
import deployProxyAdmin from "../../../deploy/ConceroProxyAdmin";
import deployParentPoolCLFCLA from "../../../deploy/ParenPoolCLFCLA";
import { CLF_SECRETS_MAINNET_EXPIRATION, CLF_SECRETS_TESTNET_EXPIRATION } from "../../../constants/CLFSecretsConfig";

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
    const deployableChains: CNetwork[] = [cNetworks[hre.network.name]];
    const isTestnet = deployableChains[0].type === "testnet";

    if (taskArgs.deployproxy) {
      await deployProxyAdmin(hre, ProxyEnum.parentPoolProxy);
      await deployTransparentProxy(hre, ProxyEnum.parentPoolProxy);
      const [proxyAddress, _] = getEnvAddress(ProxyEnum.parentPoolProxy, name);
      const { functionsSubIds } = cNetworks[name];
      await addCLFConsumer(cNetworks[name], [proxyAddress], functionsSubIds[0]);
    }

    if (taskArgs.deployimplementation) {
      await deployParentPoolCLFCLA(hre);
      await deployParentPool(hre);
      await upgradeProxyImplementation(hre, ProxyEnum.parentPoolProxy, false);
    }

    if (taskArgs.uploadsecrets) {
      await uploadDonSecrets(
        deployableChains,
        slotId,
        isTestnet ? CLF_SECRETS_TESTNET_EXPIRATION : CLF_SECRETS_MAINNET_EXPIRATION,
      );
    }

    if (taskArgs.setvars) {
      await setParentPoolVariables(deployableChains[0], slotId);
    }
  });

export default {};
