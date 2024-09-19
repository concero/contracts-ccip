import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import CNetworks, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils/getEnvVar";

interface ConstructorArgs {
  parentProxyAddress?: string;
  owner?: string;
}

const deployLPToken: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { proxyDeployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = CNetworks[name].type;

    const defaultArgs = {
      parentProxyAddress: getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`),
      owner: proxyDeployer,
    };

    const args = { ...defaultArgs, ...constructorArgs };

    console.log("Deploying LpToken...");
    const deployLPToken = (await deploy("LPToken", {
      from: proxyDeployer,
      args: [args.owner, args.parentProxyAddress],
      log: true,
      autoMine: true,
    })) as Deployment;

    if (live) {
      log(`LpToken deployed to ${name} to: ${deployLPToken.address}`, "deployLPToken");
      updateEnvVariable(`LPTOKEN_${networkEnvKeys[name]}`, deployLPToken.address, `deployments.${networkType}`);
    }
  };

export default deployLPToken;
deployLPToken.tags = ["LpToken"];
