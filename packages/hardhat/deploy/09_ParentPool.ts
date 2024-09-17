import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils";
import { poolMessengers } from "../constants";

interface ConstructorArgs {
  parentProxyAddress?: string;
  linkToken?: string;
  functionsDonId?: number;
  functionsSubId?: number;
  functionsRouter?: string;
  ccipRouter?: string;
  usdc?: string;
  lpToken?: string;
  conceroProxyAddress?: string;
  owner?: string;
  slotId?: number;
  poolMessengers?: string[];
  automationForwarder: string;
}

const deployParentPool: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = chains[name].type;
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
      conceroProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
      owner: deployer,
      poolMessengers,
    };

    // Merge defaultArgs with constructorArgs
    const args = { ...defaultArgs, ...constructorArgs };

    log("Deploying...", `deployParentPool, ${deployer}`, name);

    const deployParentPool = (await deploy("ConceroParentPool", {
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
        args.conceroProxyAddress,
        args.owner,
        args.automationforwarder,
        args.poolMessengers,
      ],
      log: true,
      autoMine: true,
    })) as Deployment;

    if (live) {
      log(`Deployed at: ${deployParentPool.address}`, "deployParentPool", name);
      updateEnvVariable(`PARENT_POOL_${networkEnvKeys[name]}`, deployParentPool.address, `deployments.${networkType}`);
    }
  };

export default deployParentPool;
deployParentPool.tags = ["ParentPool"];
