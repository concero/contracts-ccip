import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

const deployParentProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer, proxyDeployer } = await hre.getNamedAccounts();

  const { deploy } = hre.deployments;
  const { name } = hre.network;
  const implementationAddress = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);

  console.log("Deploying ParentProxy...");
  const deployParentProxy = (await deploy("ParentProxy", {
    from: proxyDeployer,
    args: [implementationAddress, proxyDeployer, "0x", deployer],
    log: true,
    autoMine: true,
    gasLimit: 2_000_000,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ParentProxy deployed to ${name} to: ${deployParentProxy.address}`, "deployParentProxy");
    updateEnvVariable(
       `PARENTPROXY_${networkEnvKeys[name]}`,
       deployParentProxy.address,
       "../../../.env.deployments",
    );
  }
};

export default deployParentProxy;
deployParentProxy.tags = ["ParentProxy"];
