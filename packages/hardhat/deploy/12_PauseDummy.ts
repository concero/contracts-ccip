import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";

const deployPauseDummy: DeployFunction = async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  console.log("Deploying PauseDummy...");
  const deployPauseDummy = (await deploy("PauseDummy", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`PauseDummy deployed to ${name} to: ${deployPauseDummy.address}`, "deployPauseDummy");
    updateEnvVariable(`CONCERO_PAUSE_${networkEnvKeys[name]}`, deployPauseDummy.address, "../../../.env.deployments");
  }
};

export default deployPauseDummy;
deployPauseDummy.tags = ["PauseDummy"];
