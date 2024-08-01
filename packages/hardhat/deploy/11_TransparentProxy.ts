import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

export enum ProxyType {
  infra,
  parentPool,
  childPool,
}
const deployTransparentProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment, proxyType: ProxyType) {
  const { proxyDeployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

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

  const initialProxyImplementationAddress = getEnvVar(`CONCERO_PAUSE_${networkEnvKeys[name]}`);
  const proxyAdminContract = getEnvVar(`${envKey}_ADMIN_CONTRACT_${networkEnvKeys[name]}`);

  console.log("Deploying TransparentProxyInfra with args:", initialProxyImplementationAddress, proxyAdminContract);

  const conceroProxyDeployment = (await deploy("TransparentUpgradeableProxy", {
    from: proxyDeployer,
    args: [initialProxyImplementationAddress, proxyAdminContract, "0x"],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`TransparentProxyInfra deployed to ${name} to: ${conceroProxyDeployment.address}`, "deployTransparentProxyInfra");
    updateEnvVariable(`${envKey}_${networkEnvKeys[name]}`, conceroProxyDeployment.address, "../../../.env.deployments");
  }
};

export default deployTransparentProxy;
deployTransparentProxy.tags = ["TransparentProxy"];
