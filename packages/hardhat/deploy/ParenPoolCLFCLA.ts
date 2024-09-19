import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { zeroAddress } from "viem";
import { poolMessengers } from "../constants/deploymentVariables";

interface ConstructorArgs {
  automationForwarder: string;
}

interface Args {
  parentProxyAddress: string;
  lpToken: string;
  USDC: string;
  clfRouter: string;
  clfSubId: string;
  clfDonId: string;
}

const deployParentPoolCLFCLA: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { proxyDeployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const cNetwork = CNetworks[name];
    const networkType = cNetwork.type;

    const { functionsRouter, functionsSubIds, functionsDonId } = cNetwork;

    const defaultArgs: Args = {
      parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
      lpToken: getEnvVar(`LPTOKEN_${networkEnvKeys[name]}`),
      USDC: getEnvVar(`USDC_${networkEnvKeys[name]}`),
      clfRouter: functionsRouter,
      clfSubId: functionsSubIds[0],
      clfDonId: functionsDonId,
    };

    const args = { ...defaultArgs, ...constructorArgs };

    console.log("Deploying LpToken...");
    const deployLPToken = (await deploy("ParentPoolCLFCLA", {
      from: proxyDeployer,
      args: [
        args.parentProxyAddress,
        args.lpToken,
        args.USDC,
        args.clfRouter,
        args.clfSubId,
        args.clfDonId,
        args.automationForwarder ?? zeroAddress,
        poolMessengers,
      ],
      log: true,
      autoMine: true,
    })) as Deployment;

    if (live) {
      log(`LpToken deployed to ${name} to: ${deployLPToken.address}`, "deployLPToken");
      updateEnvVariable(`LPTOKEN_${networkEnvKeys[name]}`, deployLPToken.address, `deployments.${networkType}`);
    }
  };

export default deployParentPoolCLFCLA;
deployParentPoolCLFCLA.tags = ["ParentPoolCLFCLA"];
