import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";
import addCLFConsumer from "../tasks/sub/add";
import log from "../utils/log";

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

  const defaultArgs = {
    slotId: 0,
    functionsRouter: functionsRouter,
    donHostedSecretsVersion: donHostedSecretsVersion,
    functionsDonId: functionsDonId,
    functionsSubId: functionsSubIds[0],
    chainSelector: chainSelector,
    conceroChainIndex: conceroChainIndex,
    linkToken: linkToken,
    ccipRouter: ccipRouter,
    priceFeed: priceFeed,
    jsCodeHashSum: {
      src: "0x46d3cb1bb1c87442ef5d35a58248785346864a681125ac50b38aae6001ceb124",
      dst: "0x07659e767a9a393434883a48c64fc8ba6e00c790452a54b5cecbf2ebb75b0173",
    },
  };

  // Merge defaultArgs with constructorArgs
  const args = { ...defaultArgs, ...constructorArgs };

  const deployment = (await deploy("Concero", {
    from: deployer,
    log: true,
    args: [
      args.functionsRouter,
      args.donHostedSecretsVersion,
      args.functionsDonId,
      // args.slotId,
      1,
      args.functionsSubId,
      args.chainSelector,
      args.conceroChainIndex,
      args.linkToken,
      args.ccipRouter,
      args.priceFeed,
      args.jsCodeHashSum,
    ],
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    log(`Contract Concero deployed to ${name} at ${deployment.address}`, "deployConcero");
    updateEnvVariable(`CONCEROCCIP_${networkEnvKeys[name]}`, deployment.address, "../../../.env.deployments");
    await addCLFConsumer(chains[name], [deployment.address], args.functionsSubId);
  }
};

export default deployConcero;
deployConcero.tags = ["Concero"];
