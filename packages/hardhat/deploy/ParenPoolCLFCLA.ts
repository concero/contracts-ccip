import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";
import { zeroAddress } from "viem";
import { poolMessengers } from "../constants/deploymentVariables";
import { getFallbackClients } from "../utils";
import chains from "../constants/cNetworks";

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

    const { publicClient: viemPublicClient } = getFallbackClients(chains[name]);
    const gasPrice = await viemPublicClient.getGasPrice();

    console.log("Deploying parent pool clf cla...");

    const deployParentPoolCLFCLA = (await deploy("ParentPoolCLFCLA", {
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
      gasPrice,
    })) as Deployment;

    if (live) {
      log(`Parent pool clf cla deployed to ${name} to: ${deployParentPoolCLFCLA.address}`, "deployParentPoolCLFCLA");
      updateEnvVariable(
        `PARENT_POOL_CLF_CLA_${networkEnvKeys[name]}`,
        deployParentPoolCLFCLA.address,
        `deployments.${networkType}`,
      );
    }
  };

export default deployParentPoolCLFCLA;
deployParentPoolCLFCLA.tags = ["ParentPoolCLFCLA"];
