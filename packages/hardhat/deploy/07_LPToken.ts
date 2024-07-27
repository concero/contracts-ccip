import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  parentProxyAddress?: string;
  owner?: string;
}

const deployLPToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const defaultArgs = {
    parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
    owner: deployer,
  };

  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying LpToken...");
  const deployLPToken = (await deploy("LPToken", {
    from: deployer,
    args: [args.owner, args.parentProxyAddress],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`LpToken deployed to ${name} to: ${deployLPToken.address}`, "deployLPToken");
    updateEnvVariable(`LPTOKEN_${networkEnvKeys[name]}`, deployLPToken.address, "../../../.env.deployments");
  }
};

export default deployLPToken;
deployLPToken.tags = ["LpToken"];
