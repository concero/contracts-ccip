import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

const deployConceroDexSwap: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  const conceroProxyAddress = getEnvVar(`CONCEROPROXY_${networkEnvKeys[name]}`);

  console.log("Deploying ConceroDexSwap...");
  const deployResult = (await deploy("DexSwap", {
    from: deployer,
    args: [conceroProxyAddress],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ConceroDexSwap deployed to ${name} to: ${deployResult.address}`, "ConceroDexSwap");
    updateEnvVariable(`CONCERO_DEX_SWAP_${networkEnvKeys[name]}`, deployResult.address, "../../../.env.deployments");
  }
};

export default deployConceroDexSwap;
deployConceroDexSwap.tags = ["ConceroDexSwap"];
