import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";

/* run with: yarn deploy --network avalancheFuji --tags Concero */
const deployConcero: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  if (!chains[name]) throw new Error(`Chain ${name} not supported`);

  const {
    linkToken,
    ccipRouter,
    functionsRouter,
    functionsDonId,
    chainSelector,
    functionsSubIds,
    conceroChainIndex,
    donHostedSecretsVersion,
  } = chains[name];

  const deployment = (await deploy("Concero", {
    from: deployer,
    log: true,
    args: [
      functionsRouter,
      donHostedSecretsVersion,
      functionsDonId,
      1,
      functionsSubIds[0],
      chainSelector,
      conceroChainIndex,
      linkToken,
      ccipRouter,
    ],
    autoMine: true,
  })) as Deployment;

  if (name !== "hardhat" && name !== "localhost") {
    try {
      const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(
        functionsRouter,
        deployment.address,
        functionsSubIds[0],
      );
    } catch (e) {}
    console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
    updateEnvVariable(`CONCEROCCIP_${networkEnvKeys[name]}`, deployment.address, "../../../.env.deployments");
  }
};

export default deployConcero;
deployConcero.tags = ["Concero"];
