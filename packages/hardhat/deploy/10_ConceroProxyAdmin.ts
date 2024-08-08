import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks from "../constants/CNetworks";
import { updateEnvAddress } from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { ProxyType } from "../constants/deploymentVariables";

const deployProxyAdmin: (hre: HardhatRuntimeEnvironment, proxyType: ProxyType) => Promise<void> = async function (
  hre: HardhatRuntimeEnvironment,
  proxyType: ProxyType,
) {
  const { proxyDeployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const networkType = CNetworks[name].type;

  const initialOwner = getEnvVar(`PROXY_DEPLOYER_ADDRESS`);

  log("Deploying...", `deployProxyAdmin: ${proxyType}`, name);
  const deployProxyAdmin = (await deploy("ConceroProxyAdmin", {
    from: proxyDeployer,
    args: [initialOwner],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`Deployed at: ${deployProxyAdmin.address}`, `deployProxyAdmin: ${proxyType}`, name);
    updateEnvAddress(`${proxyType}Admin`, name, deployProxyAdmin.address, `deployments.${networkType}`);
  }
};

export default deployProxyAdmin;
deployProxyAdmin.tags = ["ConceroProxyAdmin"];
