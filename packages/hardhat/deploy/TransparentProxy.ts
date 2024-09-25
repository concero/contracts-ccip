import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import cNetworks from "../constants/cNetworks";
import { updateEnvAddress } from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvAddress } from "../utils/getEnvVar";
import { writeContractConfig } from "../constants/deploymentVariables";
import { IProxyType } from "../types/deploymentVariables";

const deployTransparentProxy: (hre: HardhatRuntimeEnvironment, proxyType: IProxyType) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, proxyType: IProxyType) {
    const { proxyDeployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = cNetworks[name].type;

    const [initialImplementation, initialImplementationAlias] = getEnvAddress("pause", name);
    const [proxyAdmin, proxyAdminAlias] = getEnvAddress(`${proxyType}Admin`, name);

    log("Deploying...", `deployTransparentProxy:${proxyType}`, name);

    const conceroProxyDeployment = (await deploy("TransparentUpgradeableProxy", {
      from: proxyDeployer,
      args: [initialImplementation, proxyAdmin, "0x"],
      log: true,
      autoMine: true,
      gasLimit: writeContractConfig.gas,
    })) as Deployment;

    if (live) {
      log(
        `Deployed at: ${conceroProxyDeployment.address}. Initial impl: ${initialImplementationAlias}, Proxy admin: ${proxyAdminAlias}`,
        `deployTransparentProxy: ${proxyType}`,
        name,
      );
      updateEnvAddress(proxyType, name, conceroProxyDeployment.address, `deployments.${networkType}`);
    }
  };

export default deployTransparentProxy;
deployTransparentProxy.tags = ["TransparentProxy"];
