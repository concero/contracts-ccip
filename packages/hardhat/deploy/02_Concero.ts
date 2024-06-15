import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import log from "../utils/log";
import getHashSum from "../utils/getHashSum";
import path from "path";
import fs from "fs";
import { getEnvVar } from "../utils/getEnvVar";

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
}

/* run with: yarn deploy --network avalancheFuji --tags Concero */
const deployConcero: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
  constructorArgs: ConstructorArgs = {},
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;

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
    jsCodeHashSum: {
      src: getHashSum(getJS(jsPath, "SRC")),
      dst: getHashSum(getJS(jsPath, "DST")),
    },
    ethersHashSum: getHashSum(
      await (
        await fetch("https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js")
      ).text(),
    ),
    functionsVars: {
      donHostedSecretsSlotId: constructorArgs.soltid || 0,
      donHostedSecretsVersion: donHostedSecretsVersion,
      subscriptionId: functionsSubIds[0],
      donId: functionsDonId,
      functionsRouter: functionsRouter,
    },
    conceroPoolAddress: getEnvVar(`CONCEROPOOL_${networkEnvKeys[name]}`),
    conceroProxyAddress: getEnvVar(`CONCEROPROXY_${networkEnvKeys[name]}`),
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  const deployment = (await deploy("Concero", {
    from: deployer,
    log: true,
    args: [
      args.functionsVars,
      args.chainSelector,
      args.conceroChainIndex,
      args.linkToken,
      args.ccipRouter,
      args.jsCodeHashSum,
      args.ethersHashSum,
      args.dexSwapModule,
      args.conceroPoolAddress,
      args.conceroProxyAddress,
    ],
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`Contract Concero deployed to ${name} at ${deployment.address}`, "deployConcero");
    updateEnvVariable(`CONCEROCCIP_${networkEnvKeys[name]}`, deployment.address, "../../../.env.deployments");
  }
};

export default deployConcero;
deployConcero.tags = ["Concero"];
