import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  parentProxyAddress?: string;
  linkToken?: string;
  functionsDonId?: number;
  functionsSubIds?: number;
  functionsRouter?: string;
  ccipRouter?: string;
  usdc?: string;
  lpToken?: string;
  automation?: string;
  conceroProxyAddress?: string;
  owner?: string;
}

const deployParentPool: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

  const { linkToken, ccipRouter, functionsRouter, functionsDonId, functionsSubIds } = chains[name];

  const defaultArgs = {
    parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
    linkToken: linkToken,
    functionsDonId: functionsDonId,
    functionsSubId: functionsSubIds[0],
    functionsRouter: functionsRouter,
    ccipRouter: ccipRouter,
    usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
    lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
    automation: getEnvVar(`CONCERO_AUTOMATION_${networkEnvKeys[name]}`),
    conceroProxyAddress: getEnvVar(`CONCERO_PROXY_${networkEnvKeys[name]}`),
    owner: deployer,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  console.log("Deploying ParentPool...");
  const deployParentPool = (await deploy("ParentPool", {
    from: deployer,
    args: [
      args.parentProxyAddress,
      args.linkToken,
      args.functionsDonId,
      args.functionsSubId,
      args.functionsRouter,
      args.ccipRouter,
      args.usdc,
      args.lpToken,
      args.automation,
      args.conceroProxyAddress,
      args.owner,
    ],
    log: true,
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`ParentPool deployed to ${name} to: ${deployParentPool.address}`, "deployParentPool");
    updateEnvVariable(`PARENT_POOL_${networkEnvKeys[name]}`, deployParentPool.address, "../../../.env.deployments");
  }
};

export default deployParentPool;
deployParentPool.tags = ["ParentPool"];
