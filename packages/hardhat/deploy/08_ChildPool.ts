import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { messengers } from "../constants/deploymentVariables";

interface ConstructorArgs {
  conceroProxyAddress?: string;
  parentProxyAddress?: string;
  childProxyAddress?: string;
  linkToken?: string;
  ccipRouter?: string;
  chainSelector?: number;
  usdc?: string;
  owner?: string;
  messengers?: string[];
}

const deployChildPool: DeployFunction = async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}, isMainnet = false) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const { linkToken, ccipRouter, chainSelector } = chains[name];

  const defaultArgs = {
    conceroProxyAddress: getEnvVar(`CONCERO_PROXY_${networkEnvKeys[name]}`),
    childProxyAddress: getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`),
    linkToken: linkToken,
    ccipRouter: ccipRouter,
    usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
    owner: deployer,
    messengers,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ChildPool...");
  const deployChildPool = (await deploy("ConceroChildPool", {
    from: deployer,
    args: [args.conceroProxyAddress, args.childProxyAddress, args.linkToken, args.ccipRouter, args.usdc, args.owner, args.messengers],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ConceroChildPool deployed to ${name} to: ${deployChildPool.address}`, "deployConceroChildPool");
    updateEnvVariable(`CHILD_POOL_${networkEnvKeys[name]}`, deployChildPool.address, "../../../.env.deployments");
  }
};

export default deployChildPool;
deployChildPool.tags = ["ChildPool"];
