import { Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import conceroNetworks, { networkEnvKeys } from "../constants/conceroNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import { getEnvVar } from "../utils";

interface ConstructorArgs {
  linkToken?: string;
  ccipRouter?: string;
}

const deployConceroPool: (hre: HardhatRuntimeEnvironment, constructorArgs?: ConstructorArgs) => Promise<void> =
  async function (hre: HardhatRuntimeEnvironment, constructorArgs: ConstructorArgs = {}) {
    const { deployer } = await hre.getNamedAccounts();
    const { deploy } = hre.deployments;
    const { name, live } = hre.network;
    const networkType = conceroNetworks[name].type;

    const { linkToken, ccipRouter } = conceroNetworks[name];

    const defaultArgs = {
      linkToken: linkToken,
      ccipRouter: ccipRouter,
      conceroProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
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

    if (live) {
      log(`ConceroPool deployed to ${name} to: ${deployConceroPool.address}`, "deployConceroPool");
      updateEnvVariable(`CONCEROPOOL_${networkEnvKeys[name]}`, deployConceroPool.address, `deployments.${networkType}`);
    }
  };

export default deployConceroPool;
deployConceroPool.tags = ["ConceroPool"];
