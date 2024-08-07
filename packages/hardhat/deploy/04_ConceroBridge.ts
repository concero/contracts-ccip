import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import path from "path";
import fs from "fs";
import { getEnvVar } from "../utils/getEnvVar";
import { messengers } from "../constants/deploymentVariables";

interface ConstructorArgs {
  slotId?: number;
  functionsRouter?: string;
  donHostedSecretsVersion?: number;
  functionsDonId?: string;
  functionsSubId?: string;
  chainSelector?: string;
  conceroChainIndex?: number;
  linkToken?: string;
  ccipRouter?: string;
  dexSwapModule?: string;
  messengers?: string[];
}

/* run with: yarn deploy --network avalancheFuji --tags Concero */
const deployConceroBridge: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name, live } = hre.network;

  if (!chains[name]) throw new Error(`Chain ${name} not supported`);

  const {
    functionsRouter,
    donHostedSecretsVersion,
    functionsDonId,
    functionsSubIds,
    chainSelector,
    conceroChainIndex,
    linkToken,
    ccipRouter,
    priceFeed,
  } = chains[name];

  const jsPath = "./tasks/CLFScripts";

  function getJS(jsPath: string, type: string): string {
    // const source = path.join(jsPath, "src", `${type}.js`);
    const dist = path.join(jsPath, "dist", `${type}.min.js`);
    //
    // if (!fs.existsSync(dist)) {
    //   log(`File not found: ${dist}, building...`, "getJS");
    //   buildScript(source);
    // }

    return fs.readFileSync(dist, "utf8");
  }

  const defaultArgs = {
    chainSelector: chainSelector,
    conceroChainIndex: conceroChainIndex,
    linkToken: linkToken,
    ccipRouter: ccipRouter,
    dexSwapModule: getEnvVar(`CONCERO_DEX_SWAP_${networkEnvKeys[name]}`),
    functionsVars: {
      donHostedSecretsSlotId: constructorArgs.slotId || 0,
      donHostedSecretsVersion: donHostedSecretsVersion,
      subscriptionId: functionsSubIds[0],
      donId: functionsDonId,
      functionsRouter: functionsRouter,
    },
    conceroPoolAddress:
      name === "base" || name === "baseSepolia"
        ? getEnvVar(`PARENT_POOL_PROXY_${networkEnvKeys[name]}`)
        : getEnvVar(`CHILD_POOL_PROXY_${networkEnvKeys[name]}`),
    conceroProxyAddress: getEnvVar(`CONCERO_INFRA_PROXY_${networkEnvKeys[name]}`),
    messengers,
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  const deployment = (await deploy("ConceroBridge", {
    from: deployer,
    log: true,
    args: [
      args.functionsVars,
      args.chainSelector,
      args.conceroChainIndex,
      args.linkToken,
      args.ccipRouter,
      args.dexSwapModule,
      args.conceroPoolAddress,
      args.conceroProxyAddress,
      args.messengers,
    ],
    autoMine: true,
  })) as Deployment;

  if (live) {
    log(`Contract ConceroBridge deployed to ${name} at ${deployment.address}`, "deployConceroBridge");
    updateEnvVariable(`CONCERO_BRIDGE_${networkEnvKeys[name]}`, deployment.address, "../../../.env.deployments");
  }
};

export default deployConceroBridge;
deployConceroBridge.tags = ["ConceroBridge"];
