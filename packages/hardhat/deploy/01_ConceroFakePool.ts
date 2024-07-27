import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  linkToken?: string;
  ccipRouter?: string;
}

const deployConceroPool: DeployFunction = async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const { linkToken, ccipRouter } = chains[name];

  const defaultArgs = {
    linkToken: linkToken,
    ccipRouter: ccipRouter,
    conceroProxyAddress: getEnvVar(`CONCERO_PROXY_${networkEnvKeys[name]}`),
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ConceroPool...");
  // const deployConceroPool = (await deploy("ConceroPool", {
  const deployConceroPool = (await deploy("FakePool", {
    from: deployer,
    // args: [args.linkToken, args.ccipRouter, args.conceroProxyAddress],
    args: [args.ccipRouter, args.conceroProxyAddress],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ConceroPool deployed to ${name} to: ${deployConceroPool.address}`, "deployConceroPool");
    updateEnvVariable(`CONCEROPOOL_${networkEnvKeys[name]}`, deployConceroPool.address, "../../../.env.deployments");
  }
};

export default deployConceroPool;
deployConceroPool.tags = ["ConceroPool"];
