import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  conceroProxyAddress?: string;
  parentProxyAddress?: string;
  childProxyAddress?: string;
  linkToken?: string;
  ccipRouter?: string;
  chainSelector?: number;
  usdc?: string;
  owner?: string;
}

const deployChildPool: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const { linkToken, ccipRouter, chainSelector } = chains[name];

  const defaultArgs = {
    conceroProxyAddress: getEnvVar(`CONCEROPROXY_${networkEnvKeys[name]}`),
    parentProxyAddress: getEnvVar(`PARENTPROXY_${networkEnvKeys[name]}`),
    childProxyAddress: getEnvVar(`CHILDPROXY_${networkEnvKeys[name]}`),
    linkToken: linkToken,
    ccipRouter: ccipRouter,
    chainSelector: chainSelector,
    usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
    owner: deployer,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ChildPool...");
  const deployChildPool = (await deploy("ChildPool", {
    from: deployer,
    args: [
      args.conceroProxyAddress,
      args.parentProxyAddress,
      args.childProxyAddress,
      args.linkToken,
      args.ccipRouter,
      args.chainSelector,
      args.usdc,
      args.owner,
    ],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ChildPool deployed to ${name} to: ${deployChildPool.address}`, "deployChildPool");
    updateEnvVariable(`CHILDPOOL_${networkEnvKeys[name]}`, deployChildPool.address, "../../../.env.deployments");
  }
};

export default deployChildPool;
deployChildPool.tags = ["ChildPool"];
