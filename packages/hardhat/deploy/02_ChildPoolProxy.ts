import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

const deployChildProxy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer, proxyDeployer } = await hre.getNamedAccounts();

  const { deploy } = hre.deployments;
  const { name } = hre.network;
  const implementationAddress = getEnvVar(`CONCEROCCIP_${networkEnvKeys[name]}`);

  console.log("Deploying ChildProxy...");
  const deployChildProxy = (await deploy("ChildProxy", {
    from: proxyDeployer,
    args: [implementationAddress, proxyDeployer, "0x", deployer],
    log: true,
    autoMine: true,
    gasLimit: 2_000_000,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ChildProxy deployed to ${name} to: ${deployChildProxy.address}`, "deployChildProxy");
    updateEnvVariable(`CHILDPROXY_${networkEnvKeys[name]}`, deployChildProxy.address, "../../../.env.deployments");
  }
};

export default deployChildProxy;
deployChildProxy.tags = ["ChildProxy"];
