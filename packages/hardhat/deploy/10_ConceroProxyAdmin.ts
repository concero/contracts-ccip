import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { ProxyType } from "./11_TransparentProxy";

const deployProxyAdmin: DeployFunction = async function (hre: HardhatRuntimeEnvironment, proxyType: ProxyType) {
  const { proxyDeployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const networkType = CNetworks[name].type;

  const initialOwner = getEnvVar(`PROXY_DEPLOYER_ADDRESS`);

  let envKey: string;
  switch (proxyType) {
    case ProxyType.infra:
      envKey = `CONCERO_INFRA_PROXY`;
      break;
    case ProxyType.parentPool:
      envKey = `PARENT_POOL_PROXY`;
      break;
    case ProxyType.childPool:
      envKey = `CHILD_POOL_PROXY`;
      break;
    default:
      throw new Error("Invalid ProxyType");
  }

  console.log("Deploying ProxyAdmin...");
  const deployProxyAdmin = (await deploy("ConceroProxyAdmin", {
    from: proxyDeployer,
    args: [initialOwner],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`ProxyAdmin deployed to ${name} to: ${deployProxyAdmin.address}`, "deployProxyAdmin");
    updateEnvVariable(
      `${envKey}_ADMIN_CONTRACT_${networkEnvKeys[name]}`,
      deployProxyAdmin.address,
      `deployments.${networkType}`,
    );
  }
};

export default deployProxyAdmin;
deployProxyAdmin.tags = ["ConceroProxyAdmin"];
