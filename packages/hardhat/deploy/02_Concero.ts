import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../constants/CNetworks";

/* run with: yarn deploy --network avalancheFuji --tags Concero */
const deployConcero: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  if (!chains[name]) {
    throw new Error(`Chain ${name} not supported`);
  }
  const { linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, donHostedSecretsVersion, conceroChainIndex } = chains[name];

  // return console.log([functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, conceroChainIndex, linkToken, ccipRouter]);
  const deployment = (await deploy("Concero", {
    from: deployer,
    log: true,
    args: [functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, conceroChainIndex, linkToken, ccipRouter],
    autoMine: true,
  })) as Deployment;

  // const cCombined = await hre.ethers.getContract<Concero>("Concero", deployer);
  if (name !== "hardhat" && name !== "localhost") {
    const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, deployment.address, functionsSubIds[0]);
    console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
  }
};

export default deployConcero;
deployConcero.tags = ["Concero"];
