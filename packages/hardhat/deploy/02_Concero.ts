import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains, { networkEnvKeys } from "../constants/CNetworks";
import updateEnvVariable from "../utils/updateEnvVariable";

/* run with: yarn deploy --network avalancheFuji --tags Concero */
const deployConcero: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  if (!chains[name]) {
    throw new Error(`Chain ${name} not supported`);
  }
  const { linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, conceroChainIndex } = chains[name];
  const donHostedSecretsVersion = process.env[`CLF_DON_SECRETS_VERSION_${networkEnvKeys[name]}`]; // gets up-to-date env variable

  // return console.log([functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, conceroChainIndex, linkToken, ccipRouter]);
  const deployment = (await deploy("Concero", {
    from: deployer,
    log: true,
    args: [functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, conceroChainIndex, linkToken, ccipRouter],
    autoMine: true, // only for local testing
  })) as Deployment;

  // const cCombined = await hre.ethers.getContract<Concero>("Concero", deployer);
  if (name !== "hardhat" && name !== "localhost") {
    updateEnvVariable(`CONCEROCCIP_${networkEnvKeys[name]}`, deployment.address, "../../../.env");
    // console.log(`Deployed to ${name} at address ${deployment.address}`);
    // const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, deployment.address, functionsSubIds[0]);
    // console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
  }
};

export default deployConcero;
deployConcero.tags = ["Concero"];
