import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";

const deployPauseDummy: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const networkType = CNetworks[name].type;

  console.log("Deploying PauseDummy...");

  const deployPauseDummy = (await deploy("PauseDummy", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`PauseDummy deployed to ${name} to: ${deployPauseDummy.address}`, "deployPauseDummy");
    updateEnvVariable(`CONCERO_PAUSE_${networkEnvKeys[name]}`, deployPauseDummy.address, `deployments.${networkType}`);
  }
};

export default deployPauseDummy;
deployPauseDummy.tags = ["PauseDummy"];
