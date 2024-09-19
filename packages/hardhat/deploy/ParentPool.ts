import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { poolMessengers } from "../constants/deploymentVariables";
import { zeroAddress } from "viem";

interface ConstructorArgs {
  automationForwarder?: string;
}

interface Args {
  parentProxyAddress: string;
  parentPoolCLFCLA: string;
  linkToken: string;
  ccipRouter: string;
  usdc: string;
  lpToken: string;
  clfRouter: string;
  infraProxyAddress: string;
  owner: string;
  poolMessengers: string[];
}

const deployParentPool: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = chains[name].type;
    const { linkToken, ccipRouter, functionsRouter, functionsDonId, functionsSubIds } = chains[name];

    const defaultArgs: Args = {
      parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
      parentPoolCLFCLA: getEnvVar(`PARENT_POOL_CLF_CLA_${networkEnvKeys[name]}`),
      linkToken: linkToken,
      ccipRouter: ccipRouter,
      usdc: getEnvVar(`USDC_${networkEnvKeys[name]}`),
      lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
      clfRouter: functionsRouter,
      infraProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
      owner: deployer,
      poolMessengers,
    };

    // Merge defaultArgs with constructorArgs
    const args = { ...defaultArgs, ...constructorArgs };

    log("Deploying...", `deployParentPool, ${deployer}`, name);

    const deployParentPool = (await deploy("ParentPool", {
      from: deployer,
      args: [
        args.parentProxyAddress,
        args.parentPoolCLFCLA,
        args.automationForwarder ?? zeroAddress,
        args.linkToken,
        args.ccipRouter,
        args.usdc,
        args.lpToken,
        args.infraProxyAddress,
        args.clfRouter,
        args.owner,
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
