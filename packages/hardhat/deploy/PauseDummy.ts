import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import cNetworks, { networkEnvKeys } from "../constants/cNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";

const deployPauseDummy: (hre: HardhatRuntimeEnvironment) => Promise<void> = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;
  const networkType = cNetworks[name].type;

  console.log("Deploying...", "deployPauseDummy", name);

  const deployPauseDummy = (await deploy("PauseDummy", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`Deployed at: ${deployPauseDummy.address}`, "deployPauseDummy", name);
    updateEnvVariable(`CONCERO_PAUSE_${networkEnvKeys[name]}`, deployPauseDummy.address, `deployments.${networkType}`);
  }
};

export default deployPauseDummy;
deployPauseDummy.tags = ["PauseDummy"];
