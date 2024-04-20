import { DeployFunction, Deployment } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import chains from "../constants/CNetworks";

/* run with: yarn deploy --network avalancheFuji --tags ConceroInfrastructure */
const deployConcero: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const { name } = hre.network;
  // if (!chains[name]) throw new Error(`Chain ${name} not supported`);
  const { linkToken, ccipRouter, functionsRouter, functionsDonId, chainSelector, functionsSubIds, donHostedSecretsVersion } = chains[name];

  const deployment = (await deploy("Concero", {
    from: deployer,
    log: true,
    args: [functionsRouter, donHostedSecretsVersion, functionsDonId, functionsSubIds[0], chainSelector, linkToken, ccipRouter],
    autoMine: true,
  })) as Deployment;

  // const cCombined = await hre.ethers.getContract<Concero>("Concero", deployer);
  if (name !== "hardhat" && name !== "localhost") {
    const CLFunctionsConsumerTXHash = await hre.chainlink.functions.addConsumer(functionsRouter, deployment.address, functionsSubIds[0]);
    console.log(`CL Functions Consumer added successfully: ${CLFunctionsConsumerTXHash}`);
  }

  // exec(
  //   `npx hardhat verify --network polygonMumbai ${contractAddress} ${router} ${donId} ${functionsSubId} ${donHostedSecretsVersion} ${chainSelector}`,
  //   (error, stdout, stderr) => {
  //     if (error) {
  //       console.error(`ERROR: ${error}`);
  //       return;
  //     }
  //     console.log(`SUCCESS`);
  //   },
  // );
};

export default deployConcero;
deployConcero.tags = ["ConceroInfrastructure"];
