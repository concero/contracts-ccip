import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";

interface ConstructorArgs {
  linkToken?: string;
  ccipRouter?: string;
}

const deployConceroPool: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const { linkToken, ccipRouter } = chains[name];

  const defaultArgs = {
    linkToken: linkToken,
    ccipRouter: ccipRouter,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ConceroPool...");
  const deployConceroPool = (await deploy("ConceroPool", {
    from: deployer,
    args: [args.linkToken, args.ccipRouter],
    log: true,
    autoMine: true,
  })) as Deployment;

  log(`ConceroPool deployed to ${name} to: ${deployConceroPool.address}`, "deployConceroPool");
  // updateEnvVariable(`ConceroPool ${networkEnvKeys[name]}`, deployConceroPool.address, "../../../.env.deployments")
};

export default deployConceroPool;
deployConceroPool.tags = ["ConceroPool"];
